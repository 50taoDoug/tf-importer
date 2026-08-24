#!/usr/bin/env bash

VALID_ENVIRONMENTS=("dev" "qa" "prd" "demo")

terraform_get_project_name() {
    local env_conf="${PROJECT_ROOT}/config/environments.conf"
    local name
    name=$(grep "^PROJECT_NAME=" "$env_conf" 2>/dev/null | cut -d'=' -f2 | tr -d '[:space:]')
    echo "${name:-default}"
}

terraform_get_project_region() {
    local env_conf="${PROJECT_ROOT}/config/environments.conf"
    local region
    region=$(grep "^PROJECT_REGION=" "$env_conf" 2>/dev/null | cut -d'=' -f2 | tr -d '[:space:]')
    echo "$region"
}

terraform_get_account_field() {
    local account_key="$1"
    local field="$2"
    local env_conf="${PROJECT_ROOT}/config/environments.conf"
    local index
    local value

    [[ "$account_key" =~ ^[a-z0-9][a-z0-9-]*$ ]] || return 1
    [[ "$field" =~ ^(ID|PROFILE|ENVIRONMENTS|RESOURCE_EXPLORER)$ ]] || return 1

    while IFS='=' read -r index _; do
        [[ -n "$index" ]] || continue
        value=$(grep "^ACCOUNT_${index}_KEY=" "$env_conf" 2>/dev/null |
            cut -d'=' -f2- | tr -d '[:space:]')
        if [[ "$value" == "$account_key" ]]; then
            grep "^ACCOUNT_${index}_${field}=" "$env_conf" 2>/dev/null |
                cut -d'=' -f2- | tr -d '[:space:]'
            return 0
        fi
    done < <(sed -nE 's/^ACCOUNT_([0-9]+)_KEY=.*/\1=key/p' "$env_conf")
    return 1
}

terraform_get_account_index() {
    local account_key="$1"
    local env_conf="${PROJECT_ROOT}/config/environments.conf"
    local index value

    [[ "$account_key" =~ ^[a-z0-9][a-z0-9-]*$ ]] || return 1
    while IFS='=' read -r index _; do
        [[ -n "$index" ]] || continue
        value=$(grep "^ACCOUNT_${index}_KEY=" "$env_conf" 2>/dev/null |
            cut -d'=' -f2- | tr -d '[:space:]')
        if [[ "$value" == "$account_key" ]]; then
            printf '%s' "$index"
            return 0
        fi
    done < <(sed -nE 's/^ACCOUNT_([0-9]+)_KEY=.*/\1=key/p' "$env_conf")
    return 1
}

terraform_get_scoped_modularization_value() {
    local key="$1"
    local account_index=""
    local value=""

    [[ "$key" =~ ^(COST_CENTER|STATE_BUCKET|STATE_KEY_PREFIX|TAGS_MODULE_SOURCE)$ ]] || {
        terraform_get_modularization_value "$key"
        return
    }
    if [[ -n "${TF_ACCOUNT_KEY:-}" ]]; then
        account_index=$(terraform_get_account_index "$TF_ACCOUNT_KEY") || true
        if [[ -n "$account_index" ]]; then
            value=$(grep "^ACCOUNT_${account_index}_${key}=" \
                "${PROJECT_ROOT}/config/environments.conf" 2>/dev/null |
                cut -d'=' -f2- | tr -d '[:space:]')
        fi
    fi
    if [[ -n "$value" ]]; then
        printf '%s' "$value"
    else
        terraform_get_modularization_value "$key"
    fi
}

terraform_list_account_keys() {
    local env_conf="${PROJECT_ROOT}/config/environments.conf"
    sed -nE 's/^ACCOUNT_[0-9]+_KEY=([^#[:space:]]+).*/\1/p' "$env_conf" |
        sort -u
}

terraform_validate_account_registry() {
    local env_conf="${PROJECT_ROOT}/config/environments.conf"
    local selected_account="${1:-}"
    local account_key account_id profile environments environment
    local -a keys=()

    if [[ -n "$selected_account" ]]; then
        keys=("$selected_account")
    else
        mapfile -t keys < <(terraform_list_account_keys)
    fi
    [[ "${#keys[@]}" -eq 0 ]] && return 0

    for account_key in "${keys[@]}"; do
        account_id=$(terraform_get_account_field "$account_key" ID) || {
            log_error "Account '$account_key' has no ACCOUNT_*_ID in $env_conf"
            return 1
        }
        profile=$(terraform_get_account_field "$account_key" PROFILE) || {
            log_error "Account '$account_key' has no ACCOUNT_*_PROFILE in $env_conf"
            return 1
        }
        environments=$(terraform_get_account_field "$account_key" ENVIRONMENTS) || {
            log_error "Account '$account_key' has no ACCOUNT_*_ENVIRONMENTS in $env_conf"
            return 1
        }
        [[ "$account_id" =~ ^[0-9]{12}$ ]] || {
            log_error "Invalid account ID for '$account_key' in $env_conf"
            return 1
        }
        [[ -n "$profile" ]] || {
            log_error "Empty AWS profile for '$account_key' in $env_conf"
            return 1
        }
        IFS=',' read -r -a environment_list <<< "$environments"
        for environment in "${environment_list[@]}"; do
            [[ "$environment" =~ ^(dev|qa|prd|demo)$ ]] || {
                log_error "Invalid environment '$environment' for '$account_key' in $env_conf"
                return 1
            }
        done
    done
}

terraform_get_modularization_value() {
    local key="$1"
    local config_file="${PROJECT_ROOT}/config/modularization.conf"
    grep "^${key}=" "$config_file" 2>/dev/null | cut -d'=' -f2-
}

terraform_get_destination_project_dir() {
    local configured_path
    configured_path=$(terraform_get_modularization_value "DESTINATION_PROJECT_DIR")
    if [[ -z "$configured_path" ]]; then
        return 1
    fi
    realpath -m "${PROJECT_ROOT}/${configured_path}"
}

terraform_generate_versions_file() {
    local output_dir="$1"
    local terraform_constraint
    terraform_constraint=$(terraform_get_modularization_value \
        "TERRAFORM_VERSION_CONSTRAINT")
    local aws_provider_constraint
    aws_provider_constraint=$(terraform_get_modularization_value \
        "AWS_PROVIDER_VERSION_CONSTRAINT")

    if [[ -z "$terraform_constraint" || -z "$aws_provider_constraint" ]]; then
        log_error "Terraform or AWS provider version constraint is not configured."
        return 1
    fi

    mkdir -p "$output_dir"
    cat > "${output_dir}/versions.tf" << VERSIONS_EOF
terraform {
  required_version = "${terraform_constraint}"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "${aws_provider_constraint}"
    }
  }
}
VERSIONS_EOF
}

terraform_prepare_destination_project() {
    local destination_project_dir
    destination_project_dir=$(terraform_get_destination_project_dir) || return 1
    local configured_template_dir
    configured_template_dir=$(terraform_get_modularization_value "DESTINATION_TEMPLATE_DIR")
    local template_dir
    template_dir=$(realpath -m "${PROJECT_ROOT}/${configured_template_dir}")

    if [[ -z "$configured_template_dir" || ! -d "$template_dir" ]]; then
        log_error "Destination template directory not found: $template_dir"
        return 1
    fi

    if [[ -e "$destination_project_dir" ]]; then
        log_info "Destination project already exists: $destination_project_dir"
        terraform_ensure_destination_git_privacy "$destination_project_dir"
        return $?
    fi

    log_info "Creating destination project from template: $destination_project_dir"
    mkdir -p "$destination_project_dir" || return 1
    cp -a "${template_dir}/." "$destination_project_dir/" || return 1
    terraform_ensure_destination_git_privacy "$destination_project_dir" ||
        return 1
    log_success "Destination project created."
}

terraform_ensure_destination_git_privacy() {
    local destination_project_dir="$1"
    local gitignore="${destination_project_dir}/.gitignore"
    local marker="# tf-importer account output is private by default."

    if grep -Fqx "$marker" "$gitignore" 2>/dev/null; then
        return 0
    fi

    {
        printf '\n%s\n' "$marker"
        printf '%s\n' \
            '# Publication is always an explicit user decision (`git add -f <path>`).' \
            '/terraform/' \
            '/docs/inventory/'
    } >> "$gitignore"
}

terraform_validate_modularization_config() {
    local config_file="${PROJECT_ROOT}/config/modularization.conf"
    if [[ ! -f "$config_file" ]]; then
        log_error "File not found: $config_file"
        return 1
    fi

    local destination_project_dir
    destination_project_dir=$(terraform_get_destination_project_dir)
    local destination_template_dir
    destination_template_dir=$(terraform_get_modularization_value "DESTINATION_TEMPLATE_DIR")
    local module_map_file
    module_map_file=$(terraform_get_modularization_value "MODULE_MAP_FILE")
    local cost_center
    cost_center=$(terraform_get_scoped_modularization_value "COST_CENTER")
    local tags_module_source
    tags_module_source=$(terraform_get_scoped_modularization_value "TAGS_MODULE_SOURCE")
    local state_bucket
    state_bucket=$(terraform_get_scoped_modularization_value "STATE_BUCKET")
    local state_key_prefix
    state_key_prefix=$(terraform_get_scoped_modularization_value "STATE_KEY_PREFIX")
    local terraform_version_constraint
    terraform_version_constraint=$(terraform_get_modularization_value \
        "TERRAFORM_VERSION_CONSTRAINT")
    local aws_provider_version_constraint
    aws_provider_version_constraint=$(terraform_get_modularization_value \
        "AWS_PROVIDER_VERSION_CONSTRAINT")

    if [[ -z "$destination_project_dir" || -z "$destination_template_dir" ||
          -z "$module_map_file" ||
          -z "$cost_center" || -z "$tags_module_source" ||
          -z "$state_bucket" || -z "$state_key_prefix" ||
          -z "$terraform_version_constraint" ||
          -z "$aws_provider_version_constraint" ]]; then
        log_error "Incomplete modularization configuration in $config_file"
        return 1
    fi

    if [[ ! -d "$destination_project_dir" ]]; then
        log_error "Destination project directory not found: $destination_project_dir"
        return 1
    fi
    if [[ ! -f "${destination_project_dir}/${module_map_file}" ]]; then
        log_error "Module map not found: ${destination_project_dir}/${module_map_file}"
        return 1
    fi

    jq -e 'type == "object"' "${destination_project_dir}/${module_map_file}" >/dev/null || {
        log_error "Invalid module map: ${destination_project_dir}/${module_map_file}"
        return 1
    }
}

terraform_validate_environment() {
    local env="$1"

    if [[ -n "${ACCOUNT:-}" ]]; then
        [[ "$ACCOUNT" =~ ^[a-z0-9][a-z0-9-]*$ ]] || {
            log_error "Invalid account key: '$ACCOUNT'"
            return 1
        }
        export TF_ACCOUNT_KEY="$ACCOUNT"
        terraform_validate_account_registry "$TF_ACCOUNT_KEY" || return 1
    fi

    if [[ -z "$env" ]]; then
        log_error "Environment is required. Usage: tf-importer <command> <dev|qa|prd|demo>"
        return 1
    fi

    local valid=0
    for v in "${VALID_ENVIRONMENTS[@]}"; do
        [[ "$env" == "$v" ]] && valid=1
    done
    if [[ "$valid" -eq 0 ]]; then
        log_error "Invalid environment: '$env'. Valid values: ${VALID_ENVIRONMENTS[*]}"
        return 1
    fi

    local env_conf="${PROJECT_ROOT}/config/environments.conf"
    if [[ ! -f "$env_conf" ]]; then
        log_error "File not found: $env_conf"
        return 1
    fi

    if [[ "$env" == demo && -z "${TF_ACCOUNT_KEY:-}" ]]; then
        local account_key environments
        local -a demo_accounts=()
        while IFS= read -r account_key; do
            environments=$(terraform_get_account_field "$account_key" ENVIRONMENTS) || continue
            if tr ',' '\n' <<< "$environments" | grep -Fxq demo; then
                demo_accounts+=("$account_key")
            fi
        done < <(terraform_list_account_keys)
        if [[ "${#demo_accounts[@]}" -ne 1 ]]; then
            log_error "Environment 'demo' requires exactly one registered account enabled for demo"
            return 1
        fi
        export TF_ACCOUNT_KEY="${demo_accounts[0]}"
        terraform_validate_account_registry "$TF_ACCOUNT_KEY" || return 1
    fi

    local env_upper
    env_upper=$(echo "$env" | tr '[:lower:]' '[:upper:]')
    local expected_account
    local selected_profile=""
    if [[ -n "${TF_ACCOUNT_KEY:-}" ]]; then
        expected_account=$(terraform_get_account_field "$TF_ACCOUNT_KEY" ID) || {
            log_error "Account '$TF_ACCOUNT_KEY' is not configured in $env_conf"
            return 1
        }
        local allowed_environments
        allowed_environments=$(terraform_get_account_field \
            "$TF_ACCOUNT_KEY" ENVIRONMENTS) || return 1
        if ! tr ',' '\n' <<< "$allowed_environments" |
            grep -Fxq "$env"; then
            log_error "Environment '$env' is not enabled for account '$TF_ACCOUNT_KEY'"
            return 1
        fi
        selected_profile=$(terraform_get_account_field "$TF_ACCOUNT_KEY" PROFILE) || return 1
        if [[ "${AWS_PROFILE:-}" != "$selected_profile" ]]; then
            log_error "Account '$TF_ACCOUNT_KEY' requires AWS_PROFILE=$selected_profile"
            return 1
        fi
    else
        expected_account=$(grep "^${env_upper}_ACCOUNT_ID=" \
            "$env_conf" | cut -d'=' -f2 | tr -d '[:space:]')
    fi

    if [[ -z "$expected_account" || "$expected_account" == "REPLACE_ME" ]]; then
        log_error "Expected account for '$env' is not configured in $env_conf"
        return 1
    fi

    local actual_account
    actual_account=$(aws_get_account 2>/dev/null)

    if [[ -z "$actual_account" ]]; then
        log_error "Unable to retrieve the current AWS account. Check your credentials."
        return 1
    fi

    if [[ "$actual_account" != "$expected_account" ]]; then
        log_error "Environment '$env' expects account $expected_account, but the active account is $actual_account"
        return 1
    fi

    if [[ -n "${TF_ACCOUNT_KEY:-}" ]]; then
        log_info "Account '$TF_ACCOUNT_KEY' environment '$env' confirmed (account $actual_account)"
    else
        log_info "Environment '$env' confirmed (account $actual_account)"
    fi
    return 0
}

terraform_validate_region() {
    local env_conf="${PROJECT_ROOT}/config/environments.conf"
    local region
    region=$(terraform_get_project_region)

    if [[ -z "$region" ]]; then
        log_error "PROJECT_REGION is not configured in $env_conf"
        return 1
    fi

    if [[ ! "$region" =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$ ]]; then
        log_error "Invalid PROJECT_REGION in $env_conf: '$region'"
        return 1
    fi

    export AWS_DISCOVER_REGION="$region"
    export TF_REGION="$region"
    log_info "Project region confirmed: $region"
}

terraform_set_env_context() {
    local env="$1"
    local project
    project=$(terraform_get_project_name)

    local scope="$env"
    if [[ -n "${TF_ACCOUNT_KEY:-}" ]]; then
        scope="${TF_ACCOUNT_KEY}/${env}"
    fi
    export TF_ENV_DIR="${PROJECT_ROOT}/work/${project}/${scope}"
    export TF_OUTPUT_DIR="${PROJECT_ROOT}/output/${project}/${scope}"
    export TF_REPORTS_DIR="${PROJECT_ROOT}/reports/${project}/${scope}"
    mkdir -p "$TF_ENV_DIR" "$TF_OUTPUT_DIR" "$TF_REPORTS_DIR"
}

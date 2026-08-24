#!/usr/bin/env bash

cmd_build() {
    local env="${1:-}"
    if [[ $# -gt 1 ]]; then
        log_error "Usage: tf-importer build <dev|qa|prd>. Configure PROJECT_REGION in config/environments.conf."
        return 1
    fi
    terraform_validate_region || return 1
    terraform_validate_environment "$env" || return 1
    terraform_set_env_context "$env"

    local dir="$TF_ENV_DIR"
    local plan_log="${TF_REPORTS_DIR}/plan_generate.log"
    local plan_check_log="${TF_REPORTS_DIR}/plan_check.log"

    if [[ ! -f "${dir}/provider.tf" ]]; then
        log_info "provider.tf not found; creating the default provider configuration..."
        cat > "${dir}/provider.tf" << PROVIDER_EOF
provider "aws" {
  region = "${TF_REGION}"
}
PROVIDER_EOF
    fi

    terraform_generate_versions_file "$dir" || return 1

    log_info "terraform init..."
    terraform -chdir="$dir" init -input=false || return 1

    log_info "Generating configuration (terraform plan -generate-config-out)..."
    rm -f "${dir}/auto_generated.tf"
    rm -f "${dir}"/{network,ecs,ssm,lambda,logs,elb,kms,secretsmanager,s3,events,cloudformation,iam,sns,ecr,backup,apigateway,outros}.tf
    local generate_exit_code=0
    set +e
    terraform -chdir="$dir" plan -generate-config-out=auto_generated.tf \
        > "$plan_log" 2>&1
    generate_exit_code=$?
    set -e
    if [[ $generate_exit_code -ge 128 ]]; then
        log_error \
            "Terraform configuration generation was interrupted (exit $generate_exit_code)."
        return "$generate_exit_code"
    fi
    if [[ ! -s "${dir}/auto_generated.tf" ]]; then
        log_error "Terraform did not generate a usable auto_generated.tf."
        return 1
    fi

    log_info "Applying known corrections..."
    terraform_cleanup_generated_config
    terraform_fill_ssm_values
    terraform_fill_lambda_code
    terraform_add_lambda_lifecycle

    log_info "Removing imports that failed remote reads..."
    terraform_prune_failed_imports "$plan_log"

    log_info "Removing orphan imports with no generated configuration..."
    terraform_prune_orphan_imports

    log_info "Sorting generated Terraform blocks deterministically..."
    python3 "${PROJECT_ROOT}/scripts/terraform/sort_terraform_blocks.py" \
        "${dir}/auto_generated.tf" "${dir}/imports_generated.tf" || return 1

    log_info "Formatting..."
    terraform -chdir="$dir" fmt || return 1

    log_info "Validating..."
    terraform -chdir="$dir" validate || return 1

    log_info "Checking the final plan for remaining drift..."
    local attempt=1
    local max_attempts=10
    local exit_code=0

    while [[ $attempt -le $max_attempts ]]; do
        set +e
        terraform -chdir="$dir" plan > "$plan_check_log" 2>&1
        exit_code=$?
        set -e

        if [[ $exit_code -eq 0 ]]; then
            log_info "Terraform plan completed on attempt $attempt."
            break
        fi

        if grep -q "Cannot import non-existent remote object" "$plan_check_log"; then
            log_info "Import drift detected on attempt $attempt; pruning..."
            terraform_prune_failed_imports "$plan_check_log"
            attempt=$((attempt + 1))
        else
            log_error "Plan failed for a reason unrelated to import drift. See $plan_check_log"
            return 1
        fi
    done

    if [[ $attempt -gt $max_attempts ]]; then
        log_error "Exceeded $max_attempts pruning attempts. See $plan_check_log"
        return 1
    fi

    local plan_check_plain="${plan_check_log}.plain"
    sed -r 's/\x1B\[[0-9;]*[mK]//g' "$plan_check_log" > "$plan_check_plain"
    if ! grep -Eq \
        '^Plan: [0-9]+ to import, 0 to add, 0 to change, 0 to destroy\.$' \
        "$plan_check_plain"; then
        log_error "Final plan is not import-only. See $plan_check_log"
        rm -f "$plan_check_plain"
        return 1
    fi
    rm -f "$plan_check_plain"

    log_info "Analyzing actual resource dependencies..."
    python3 "${PROJECT_ROOT}/scripts/terraform/analyze_dependencies.py" \
        "${dir}/auto_generated.tf" "${dir}/imports_generated.tf" \
        "${TF_REPORTS_DIR}/dependency_clusters.json"

    tail -8 "$plan_check_log"
}

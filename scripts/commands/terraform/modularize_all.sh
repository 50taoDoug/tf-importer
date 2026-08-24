#!/usr/bin/env bash

terraform_cleanup_active_staging() {
    local staging_dir="${TF_ACTIVE_STAGING_DIR:-}"
    local staging_root="${TF_ACTIVE_STAGING_ROOT:-}"

    if [[ -z "$staging_dir" || -z "$staging_root" || ! -d "$staging_dir" ]]; then
        return 0
    fi

    case "$staging_dir" in
        "${staging_root}"/.*.tf-importer.*)
            rm -rf -- "$staging_dir"
            ;;
        *)
            log_error "Refusing to clean unexpected staging path: $staging_dir"
            return 1
            ;;
    esac
}

terraform_remove_legacy_unified_root() {
    local destination_dir="$1"
    local destination_project_dir="$2"

    case "$destination_dir" in
        "${destination_project_dir}"/terraform/dev|\
"${destination_project_dir}"/terraform/qa|\
"${destination_project_dir}"/terraform/prd|\
"${destination_project_dir}"/terraform/*/*)
            ;;
        *)
            log_error "Refusing to clean unexpected destination: $destination_dir"
            return 1
            ;;
    esac

    rm -f -- \
        "${destination_dir}/backend.tf" \
        "${destination_dir}/imports_generated.tf" \
        "${destination_dir}/main.tf" \
        "${destination_dir}/provider.tf" \
        "${destination_dir}/versions.tf"
    rm -rf -- "${destination_dir}/lambda_code"
}

terraform_install_staging_traps() {
    trap 'terraform_cleanup_active_staging' EXIT
    trap 'terraform_cleanup_active_staging; exit 130' INT
    trap 'terraform_cleanup_active_staging; exit 143' TERM
}

terraform_clear_staging_traps() {
    trap - EXIT INT TERM
}

cmd_modularize_all() {
    local env="${1:-}"
    if [[ $# -ne 1 ]]; then
        log_error "Usage: tf-importer modularize_all <dev|qa|prd>"
        return 1
    fi

    terraform_validate_region || return 1
    terraform_validate_environment "$env" || return 1
    terraform_prepare_destination_project || return 1
    terraform_validate_modularization_config || return 1
    terraform_set_env_context "$env"

    local destination_project_dir
    destination_project_dir=$(terraform_get_destination_project_dir)
    local destination_terraform_dir="${destination_project_dir}/terraform"
    if [[ -n "${TF_ACCOUNT_KEY:-}" ]]; then
        destination_terraform_dir+="/${TF_ACCOUNT_KEY}"
    fi
    destination_terraform_dir+="/${env}"
    local module_map_relative
    module_map_relative=$(terraform_get_modularization_value "MODULE_MAP_FILE")
    local module_map="${destination_project_dir}/${module_map_relative}"
    local cost_center
    cost_center=$(terraform_get_scoped_modularization_value "COST_CENTER")
    local tags_source
    tags_source=$(terraform_get_scoped_modularization_value "TAGS_MODULE_SOURCE")
    local state_bucket
    state_bucket=$(terraform_get_scoped_modularization_value "STATE_BUCKET")
    local state_key_prefix
    state_key_prefix=$(terraform_get_scoped_modularization_value "STATE_KEY_PREFIX")
    local pipeline_report="${TF_REPORTS_DIR}/modularization_pipeline.json"
    local project_name
    project_name=$(terraform_get_project_name)
    local env_upper
    env_upper=$(printf '%s' "$env" | tr '[:lower:]' '[:upper:]')
    local account_id
    if [[ -n "${TF_ACCOUNT_KEY:-}" ]]; then
        account_id=$(terraform_get_account_field "$TF_ACCOUNT_KEY" ID)
    else
        account_id=$(grep "^${env_upper}_ACCOUNT_ID=" \
            "${PROJECT_ROOT}/config/environments.conf" | cut -d'=' -f2 | tr -d '[:space:]')
    fi

    export TF_ACTIVE_STAGING_DIR=""
    export TF_ACTIVE_STAGING_ROOT="$destination_terraform_dir"
    terraform_install_staging_traps

    mkdir -p "$destination_terraform_dir" "$TF_REPORTS_DIR"
    jq -n \
        --arg project "$project_name" \
        --arg environment "$env" \
        --arg account_key "${TF_ACCOUNT_KEY:-}" \
        --arg region "$TF_REGION" \
        --arg account_id "$account_id" \
        '{
            project: $project,
            environment: $environment,
            account_key: $account_key,
            region: $region,
            account_id: $account_id,
            categories: [],
            skipped_category_details: []
        }' > "$pipeline_report"

    local processed=0
    local skipped=0

    for category in "${CATEGORIES[@]}"; do
        local source_main="${TF_ENV_DIR}/${category}/main.tf"
        local source_imports="${TF_ENV_DIR}/${category}/imports_generated.tf"
        local source_import_count=0
        source_import_count=$(grep -c "^import {" "$source_imports" 2>/dev/null) || true

        if [[ ! -s "$source_main" || "$source_import_count" -eq 0 ]]; then
            log_info "[$category] no resources found; skipping."
            jq \
                --arg category "$category" \
                '.skipped_category_details += [{
                    category: $category,
                    reason: "No importable resources were generated."
                }]' \
                "$pipeline_report" > "${pipeline_report}.tmp" &&
                mv "${pipeline_report}.tmp" "$pipeline_report" || return 1
            skipped=$((skipped + 1))
            continue
        fi

        local output_dir="${destination_terraform_dir}/${category}"
        local staging_dir
        staging_dir=$(mktemp -d "${destination_terraform_dir}/.${category}.tf-importer.XXXXXX")
        export TF_ACTIVE_STAGING_DIR="$staging_dir"
        local plan_log="${TF_REPORTS_DIR}/modularization_${category}_plan.log"
        mkdir -p "$output_dir"

        log_info "[$category] generating provider and Terraform configuration..."
        cat > "${staging_dir}/provider.tf" << PROVIDER_EOF
provider "aws" {
  region = "${TF_REGION}"
}
PROVIDER_EOF
        terraform_generate_versions_file "$staging_dir" || return 1

        python3 "${PROJECT_ROOT}/scripts/terraform/generate_module_calls.py" \
            "$source_main" "$source_imports" "$module_map" "$staging_dir" \
            "$env" "$cost_center" "$tags_source" "$project_name" || {
                rm -rf "$staging_dir"
                return 1
            }

        if [[ "$category" == "lambda" && -d "${TF_ENV_DIR}/lambda_code" ]]; then
            mkdir -p "${staging_dir}/lambda_code"
            cp -a "${TF_ENV_DIR}/lambda_code/." "${staging_dir}/lambda_code/"
        fi

        local category_report="${staging_dir}/modularization_report.json"
        jq -e \
            --argjson expected "$source_import_count" \
            '.source_imports == $expected
             and .destination_imports == $expected
             and .source_resources == .destination_resources
             and (.missing_imports | length) == 0
             and (.orphan_imports | length) == 0' \
            "$category_report" >/dev/null || {
                log_error "[$category] source and destination counts do not match."
                rm -rf "$staging_dir"
                return 1
            }

        log_info "[$category] formatting and validating..."
        terraform -chdir="$staging_dir" fmt || {
            rm -rf "$staging_dir"
            return 1
        }
        terraform -chdir="$staging_dir" init -backend=false -input=false >/dev/null || {
            rm -rf "$staging_dir"
            return 1
        }
        terraform -chdir="$staging_dir" validate >/dev/null || {
            rm -rf "$staging_dir"
            return 1
        }

        log_info "[$category] checking import-only plan..."
        terraform -chdir="$staging_dir" plan -no-color > "$plan_log" 2>&1 || {
            log_error "[$category] terraform plan failed. See $plan_log"
            rm -rf "$staging_dir"
            return 1
        }

        if ! grep -Eq \
            '^Plan: [0-9]+ to import, 0 to add, 0 to change, 0 to destroy\.$' \
            "$plan_log"; then
            log_error "[$category] plan is not import-only. See $plan_log"
            rm -rf "$staging_dir"
            return 1
        fi

        log_info "[$category] publishing validated files..."
        terraform_generate_backend \
            "$env" "$category" "$state_bucket" "$staging_dir" "$state_key_prefix" || {
                rm -rf "$staging_dir"
                return 1
            }

        cp "${staging_dir}/main.tf" "${output_dir}/main.tf"
        cp "${staging_dir}/imports_generated.tf" "${output_dir}/imports_generated.tf"
        cp "${staging_dir}/provider.tf" "${output_dir}/provider.tf"
        cp "${staging_dir}/versions.tf" "${output_dir}/versions.tf"
        cp "${staging_dir}/backend.tf" "${output_dir}/backend.tf"
        if [[ -d "${staging_dir}/lambda_code" ]]; then
            mkdir -p "${output_dir}/lambda_code"
            cp -a "${staging_dir}/lambda_code/." "${output_dir}/lambda_code/"
        fi

        jq \
            --arg category "$category" \
            --slurpfile modularization "$category_report" \
            '.categories += [{
                category: $category,
                status: "validated",
                modularization: $modularization[0]
            }]' \
            "$pipeline_report" > "${pipeline_report}.tmp" &&
            mv "${pipeline_report}.tmp" "$pipeline_report"

        rm -rf "$staging_dir"
        export TF_ACTIVE_STAGING_DIR=""
        processed=$((processed + 1))
    done

    jq \
        --argjson processed "$processed" \
        --argjson skipped "$skipped" \
        '.processed_categories = $processed
         | .skipped_categories = $skipped
         | .source_resources = ([.categories[].modularization.source_resources] | add // 0)
         | .source_imports = ([.categories[].modularization.source_imports] | add // 0)
         | .destination_resources = ([.categories[].modularization.destination_resources] | add // 0)
         | .destination_imports = ([.categories[].modularization.destination_imports] | add // 0)
         | .modularized_resources = ([.categories[].modularization.modularized | length] | add // 0)
         | .preserved_native_resources = ([.categories[].modularization.preserved_native | length] | add // 0)
         | .shared_tag_consumers = ([
             .categories[].modularization.shared_tag_consumers // []
           ] | flatten | length)
         | .rewritten_reference_count = ([
             .categories[].modularization.rewritten_references[]?.occurrences // 1
           ] | add // 0)
         | .layout = "category"
         | .validation = {
             category_plans: "import-only",
             published: true
           }' \
        "$pipeline_report" > "${pipeline_report}.tmp" &&
        mv "${pipeline_report}.tmp" "$pipeline_report" || return 1

    terraform_remove_legacy_unified_root \
        "$destination_terraform_dir" "$destination_project_dir" || return 1

    local discovery_classification="${TF_REPORTS_DIR}/discovery_classification.json"
    local pruned_imports="${TF_REPORTS_DIR}/pruned_imports.json"
    local orphan_imports="${TF_REPORTS_DIR}/orphan_imports.json"
    local inventory_coverage="${TF_REPORTS_DIR}/inventory_coverage.json"
    local required_report
    for required_report in \
        "$discovery_classification" \
        "$pruned_imports" \
        "$orphan_imports"; do
        if [[ ! -s "$required_report" ]]; then
            log_error "Required inventory artifact is missing: $required_report"
            return 1
        fi
    done

    python3 "${PROJECT_ROOT}/scripts/terraform/build_inventory_coverage.py" \
        "$discovery_classification" \
        "$pruned_imports" \
        "$orphan_imports" \
        "$pipeline_report" \
        "$inventory_coverage" || return 1
    jq -e '.reconciliation.complete == true' \
        "$inventory_coverage" >/dev/null || {
            log_error "Inventory accountability reconciliation failed."
            return 1
        }
    python3 "${PROJECT_ROOT}/scripts/terraform/generate_inventory_summary.py" \
        "$inventory_coverage" \
        "$destination_project_dir" \
        "${TF_ACCOUNT_KEY:-}" || return 1

    local cross_account_report=""
    if [[ -n "${TF_ACCOUNT_KEY:-}" ]]; then
        cross_account_report="${TF_REPORTS_DIR}/cross_account_relationships.json"
        python3 "${PROJECT_ROOT}/scripts/terraform/analyze_cross_account.py" \
            "$destination_terraform_dir" \
            "${PROJECT_ROOT}/config/environments.conf" \
            "$TF_ACCOUNT_KEY" \
            "$env" \
            "$cross_account_report" || return 1
        jq -e '.reconciliation.complete == true' \
            "$cross_account_report" >/dev/null || {
                log_error "Cross-account relationship reconciliation failed."
                return 1
            }
        python3 \
            "${PROJECT_ROOT}/scripts/terraform/generate_cross_account_summary.py" \
            "$cross_account_report" \
            "$destination_project_dir" \
            "$TF_ACCOUNT_KEY" \
            "$env" || return 1
    fi

    local destination_readme="${destination_project_dir}/README.md"
    if [[ -n "${TF_ACCOUNT_KEY:-}" ]]; then
        destination_readme="${destination_terraform_dir}/README.md"
    fi
    python3 "${PROJECT_ROOT}/scripts/terraform/generate_destination_readme.py" \
        "$pipeline_report" \
        "$destination_readme" || return 1

    log_success "Modularization completed: $processed categories validated, $skipped skipped."
    log_info "Consolidated report: $pipeline_report"
    log_info "Inventory coverage report: $inventory_coverage"
    if [[ -n "$cross_account_report" ]]; then
        log_info "Cross-account relationship report: $cross_account_report"
    fi

    export TF_ACTIVE_STAGING_DIR=""
    export TF_ACTIVE_STAGING_ROOT=""
    terraform_clear_staging_traps
}

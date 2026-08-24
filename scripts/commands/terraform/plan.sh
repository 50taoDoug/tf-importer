#!/usr/bin/env bash

cmd_plan() {
    local env="${1:-}"
    if [[ $# -ne 1 ]]; then
        log_error "Usage: tf-importer plan <dev|qa|prd>"
        return 1
    fi

    terraform_validate_region || return 1
    terraform_validate_environment "$env" || return 1
    terraform_set_env_context "$env"

    if [[ ! -f "${TF_ENV_DIR}/imports_generated.tf" ]]; then
        log_error "Generated imports not found; run 'build' first."
        return 1
    fi

    local plan_log="${TF_REPORTS_DIR}/manual_plan.log"
    log_info "Running the account-validated import-only plan..."
    terraform -chdir="$TF_ENV_DIR" plan -no-color > "$plan_log" 2>&1 || {
        log_error "Terraform plan failed. See $plan_log"
        return 1
    }

    cat "$plan_log"
    if ! grep -Eq \
        '^Plan: [0-9]+ to import, 0 to add, 0 to change, 0 to destroy\.$' \
        "$plan_log"; then
        log_error "Plan is not import-only. See $plan_log"
        return 1
    fi
}

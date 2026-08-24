#!/usr/bin/env bash

cmd_discover() {
    local env="${1:-}"
    if [[ $# -gt 1 ]]; then
        log_error "Usage: tf-importer discover <dev|qa|prd>. Configure PROJECT_REGION in config/environments.conf."
        return 1
    fi
    terraform_validate_region || return 1
    terraform_validate_environment "$env" || return 1
    terraform_set_env_context "$env"

    aws_discover_environment "$env" > "${TF_OUTPUT_DIR}/discovery.json"
    log_info "Saved to ${TF_OUTPUT_DIR}/discovery.json"
}

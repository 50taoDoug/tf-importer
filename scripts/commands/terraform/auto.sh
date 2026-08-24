#!/usr/bin/env bash

cmd_auto() {
    local env="${1:-}"
    if [[ $# -gt 1 ]]; then
        log_error "Usage: tf-importer auto <dev|qa|prd>. Configure PROJECT_REGION in config/environments.conf."
        return 1
    fi
    terraform_validate_region || return 1
    terraform_validate_environment "$env" || return 1
    terraform_set_env_context "$env"

    mkdir -p "$TF_REPORTS_DIR"
    echo "[]" > "${TF_REPORTS_DIR}/pruned_imports.json"
    echo "[]" > "${TF_REPORTS_DIR}/orphan_imports.json"

    aws_discover_environment "$env" > "${TF_OUTPUT_DIR}/discovery.json"
    terraform_generate_import_blocks
}

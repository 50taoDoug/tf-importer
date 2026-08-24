#!/usr/bin/env bash

cmd_analyze() {
    local env="${1:-}"
    terraform_validate_environment "$env" || return 1
    terraform_set_env_context "$env"

    local tf_file="${TF_ENV_DIR}/auto_generated.tf"
    local imports_file="${TF_ENV_DIR}/imports_generated.tf"
    local output_file="${TF_REPORTS_DIR}/dependency_clusters.json"

    if [[ ! -f "$tf_file" || ! -f "$imports_file" ]]; then
        log_error "auto_generated.tf or imports_generated.tf not found in $TF_ENV_DIR; run 'build' first."
        return 1
    fi

    mkdir -p "$TF_REPORTS_DIR"

    log_info "Analyzing actual resource dependencies..."
    python3 "${PROJECT_ROOT}/scripts/terraform/analyze_dependencies.py" \
        "$tf_file" "$imports_file" "$output_file"
}

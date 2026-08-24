#!/usr/bin/env bash

cmd_modularize() {
    local env="${1:-}"
    terraform_validate_environment "$env" || return 1
    terraform_set_env_context "$env"

    local category="${2:-}"
    local type_config="${3:-}"
    local output_dir="${4:-}"
    local cost_center="${5:-}"
    local tags_source="${6:-}"

    if [[ -z "$category" || -z "$type_config" || -z "$output_dir" || -z "$cost_center" || -z "$tags_source" ]]; then
        log_error "Usage: tf-importer modularize <env> <category> <type_config.json> <output_dir> <cost_center> <tags_module_source>"
        return 1
    fi

    local source_main="${TF_ENV_DIR}/${category}/main.tf"
    local source_imports="${TF_ENV_DIR}/${category}/imports_generated.tf"

    if [[ ! -f "$source_main" || ! -f "$source_imports" ]]; then
        log_error "Missing $source_main or $source_imports; run 'build' first."
        return 1
    fi

    mkdir -p "$output_dir"

    python3 "${PROJECT_ROOT}/scripts/terraform/generate_module_calls.py" \
        "$source_main" "$source_imports" "$type_config" "$output_dir" \
        "$env" "$cost_center" "$tags_source" "$(terraform_get_project_name)"
}

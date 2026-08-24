#!/usr/bin/env bash

terraform_generate_backend() {
    local env="$1"
    local category="$2"
    local bucket="$3"
    local output_dir="$4"
    local state_key_prefix="$5"
    local backend_region
    backend_region=$(terraform_get_project_region)

    if [[ ! "$backend_region" =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$ ]]; then
        log_error "Invalid backend region: '$backend_region'"
        return 1
    fi

    mkdir -p "$output_dir"

    local state_scope="$env"
    if [[ -n "${TF_ACCOUNT_KEY:-}" ]]; then
        state_scope="${TF_ACCOUNT_KEY}/${env}"
    fi

    cat > "${output_dir}/backend.tf" << BACKEND_EOF
terraform {
  backend "s3" {
    bucket       = "${bucket}"
    key          = "${state_key_prefix}/${state_scope}/${category}/terraform.tfstate"
    region       = "${backend_region}"
    use_lockfile = true
    encrypt      = true
  }
}
BACKEND_EOF

    log_info "Generated: ${output_dir}/backend.tf"
}

cmd_generate_backend() {
    local env="${1:-}"
    terraform_validate_environment "$env" || return 1

    local category="${2:-}"
    local bucket="${3:-}"
    local output_dir="${4:-}"
    local state_key_prefix="${5:-tf-state}"

    if [[ -z "$category" || -z "$bucket" || -z "$output_dir" || $# -gt 5 ]]; then
        log_error "Usage: tf-importer generate_backend <env> <category> <state_bucket> <output_dir> [state_key_prefix]"
        return 1
    fi

    terraform_generate_backend "$env" "$category" "$bucket" "$output_dir" "$state_key_prefix"
}

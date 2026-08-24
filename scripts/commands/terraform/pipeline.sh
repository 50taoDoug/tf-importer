#!/usr/bin/env bash

cmd_pipeline() {
    local env="${1:-}"
    if [[ $# -ne 1 ]]; then
        log_error "Usage: tf-importer pipeline <dev|qa|prd>"
        return 1
    fi

    terraform_validate_region || return 1
    terraform_validate_environment "$env" || return 1
    terraform_prepare_destination_project || return 1
    terraform_validate_modularization_config || return 1

    log_info "Starting end-to-end pipeline for environment '$env'."
    log_info "[1/4] Discovering AWS resources and generating import blocks..."
    cmd_auto "$env" || return 1
    log_info "[2/4] Generating, correcting, and validating Terraform configuration..."
    cmd_build "$env" || return 1
    log_info "[3/4] Splitting validated resources into categories..."
    cmd_split "$env" || return 1
    log_info "[4/4] Modularizing, planning, and publishing destination categories..."
    cmd_modularize_all "$env" || return 1
    log_success "End-to-end pipeline completed for environment '$env'."
}

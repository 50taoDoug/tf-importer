#!/usr/bin/env bash

source "${PROJECT_ROOT}/scripts/core/logger.sh"
source "${PROJECT_ROOT}/scripts/core/common.sh"
source "${PROJECT_ROOT}/scripts/core/version.sh"
source "${PROJECT_ROOT}/scripts/lib/loader.sh"

declare -gA REGISTERED_COMMANDS

COMMANDS=(
  "environment/doctor"
  "general/help"
  "general/validate"
  "general/version"
  "aws/discover"
  "terraform/auto"
  "terraform/build"
  "terraform/split"
  "terraform/analyze"
  "terraform/modularize"
  "terraform/generate_backend"
  "terraform/modularize_all"
  "terraform/pipeline"
  "terraform/plan"
)

for cmd in "${COMMANDS[@]}"; do
  load_command "$cmd"
done

source "${PROJECT_ROOT}/scripts/core/dispatcher.sh"

# --- AWS provider core ---
source "${PROJECT_ROOT}/scripts/core/environment.sh"
source "${PROJECT_ROOT}/scripts/lib/aws.sh"

# --- Generic AWS discovery (Tagging API) ---
source "${PROJECT_ROOT}/scripts/providers/aws/generic_discover.sh"
source "${PROJECT_ROOT}/scripts/providers/aws/resource_explorer_discover.sh"
source "${PROJECT_ROOT}/scripts/providers/aws/eni_filter.sh"
source "${PROJECT_ROOT}/scripts/providers/aws/nacl_filter.sh"

# --- Hybrid Terraform generation pipeline ---
source "${PROJECT_ROOT}/scripts/terraform/exclude.sh"
source "${PROJECT_ROOT}/scripts/terraform/mapper.sh"
source "${PROJECT_ROOT}/scripts/terraform/categorize.sh"
source "${PROJECT_ROOT}/scripts/terraform/id_extractor.sh"
source "${PROJECT_ROOT}/scripts/terraform/import_blocks.sh"
source "${PROJECT_ROOT}/scripts/terraform/prune_failed_imports.sh"
source "${PROJECT_ROOT}/scripts/terraform/prune_orphan_imports.sh"
source "${PROJECT_ROOT}/scripts/terraform/cleanup_generated_config.sh"
source "${PROJECT_ROOT}/scripts/terraform/fill_ssm_values.sh"
source "${PROJECT_ROOT}/scripts/terraform/fill_lambda_code.sh"
source "${PROJECT_ROOT}/scripts/terraform/add_lambda_lifecycle.sh"
source "${PROJECT_ROOT}/scripts/terraform/split_generated_config.sh"

log_debug "bootstrap loaded"

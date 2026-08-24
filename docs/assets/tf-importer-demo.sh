#!/usr/bin/env bash
set -euo pipefail

# Safe, fictional terminal used only by the VHS demonstration.
# This script prints a fixed transcript and never evaluates user input.

green=$'\033[38;2;63;185;80m'
blue=$'\033[38;2;88;166;255m'
yellow=$'\033[38;2;210;153;34m'
muted=$'\033[38;2;139;148;158m'
reset=$'\033[0m'

printf '\033[2J\033[H'
printf '%sSANITIZED DEMONSTRATION — FICTIONAL DATA%s\n\n' "$yellow" "$reset"
printf '%s$%s make pipeline ACCOUNT=example-platform-prod ENV=prd\n' \
    "$green" "$reset"

sleep 2
printf '%s✓%s Environment prerequisites validated\n' "$green" "$reset"
sleep 2
printf '%s✓%s AWS account and region boundaries validated\n' "$green" "$reset"
sleep 2
printf '%s✓%s Regional resources discovered and classified: 257\n' "$green" "$reset"
sleep 2
printf '%s✓%s Dependencies analyzed and reconciled\n' "$green" "$reset"
sleep 2
printf '%s✓%s Import blocks and Terraform configuration generated\n' "$green" "$reset"
sleep 2
printf '%s✓%s Category roots modularized progressively\n' "$green" "$reset"
sleep 2
printf '%s✓%s Unmapped resources preserved as native Terraform\n' "$green" "$reset"
sleep 2
printf '%s✓%s Source, imports, and destination fully reconciled\n\n' "$green" "$reset"
sleep 2
printf '%sImport only:%s 257 to import\n' "$blue" "$reset"
sleep 2
printf '%sPlan: 0 to add, 0 to change, 0 to destroy%s\n\n' "$green" "$reset"
sleep 2
printf '%sReady for manual review%s\n' "$yellow" "$reset"
printf 'terraform apply was not executed\n'
printf '%sNo AWS or Terraform command was executed by this demo.%s\n' "$muted" "$reset"
sleep 8

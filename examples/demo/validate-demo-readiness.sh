#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly PROJECT_ROOT
failures=0
ok() { printf '[ok] %s\n' "$*"; }
bad() { printf '[fail] %s\n' "$*" >&2; failures=$((failures + 1)); }

active_demo_resource_count() {
    local mappings active arn cluster response status
    mappings="$(aws --no-cli-pager --region "$AWS_REGION" \
        resourcegroupstaggingapi get-resources \
        --tag-filters Key=Project,Values="${PROJECT_PREFIX:-tf-importer-demo}" \
        --output json)" || return 1
    active="$(jq '.ResourceTagMappingList | length' <<< "$mappings")"

    while IFS= read -r arn; do
        [[ -n "$arn" ]] || continue
        cluster="${arn##*/}"
        if response="$(aws --no-cli-pager --region "$AWS_REGION" ecs describe-clusters \
            --clusters "$cluster" --output json 2>/dev/null)"; then
            status="$(jq -r '.clusters[0].status // "MISSING"' <<< "$response")"
            if [[ "$status" == INACTIVE || "$status" == MISSING ]]; then
                active=$((active - 1))
            fi
        fi
    done < <(jq -r '.ResourceTagMappingList[].ResourceARN | select(contains(":ecs:"))' \
        <<< "$mappings")

    printf '%d\n' "$active"
}

for tool in aws terraform jq bash od; do
    if command -v "$tool" >/dev/null; then ok "$tool available"; else bad "$tool missing"; fi
done
if [[ -n "${AWS_REGION:-}" ]]; then ok "AWS_REGION explicitly set: $AWS_REGION"; else bad "AWS_REGION is not set"; fi
if command -v aws >/dev/null && [[ -n "${AWS_REGION:-}" ]]; then
    if aws --no-cli-pager --region "$AWS_REGION" sts get-caller-identity >/dev/null; then ok "AWS identity active"; else bad "AWS identity unavailable"; fi
    existing="$(active_demo_resource_count 2>/dev/null || printf unknown)"
    if [[ "$existing" == 0 ]]; then ok "no tagged demo resources detected in selected region"; else bad "existing demo resources: $existing"; fi
    readonly_checks=(
        "ec2 describe-vpcs --max-results 5"
        "s3api list-buckets --max-items 1"
        "ssm describe-parameters --max-results 1"
        "logs describe-log-groups --limit 1"
        "events list-event-buses --limit 1"
        "ecs list-clusters --max-results 1"
    )
    for check in "${readonly_checks[@]}"; do
        read -r -a args <<<"$check"
        if aws --no-cli-pager --region "$AWS_REGION" "${args[@]}" >/dev/null 2>&1; then
            ok "permission check: $check"
        else
            bad "permission unavailable or service check failed: $check"
        fi
    done
fi
for script in create-demo-resources.sh delete-demo-resources.sh; do
    if [[ -x "${SCRIPT_DIR}/${script}" ]]; then ok "$script executable"; else bad "$script is not executable"; fi
done
if git -C "$PROJECT_ROOT" check-ignore -q examples/demo/.demo-state/resources.tsv; then ok "local demo state is ignored"; else bad "demo state is not ignored"; fi
if git -C "$PROJECT_ROOT" check-ignore -q config/environments.conf; then ok "private environment config is ignored"; else bad "private environment config is not ignored"; fi
if git -C "$PROJECT_ROOT" check-ignore -q config/modularization.conf; then ok "private modularization config is ignored"; else bad "private modularization config is not ignored"; fi
printf '%s\n' 'Manual checks: 1920x1080 capture; terminal >=18pt; notifications off; identifiers cropped/blurred.'
(( failures == 0 )) || exit 1

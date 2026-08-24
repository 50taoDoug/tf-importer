#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly STATE_FILE="${SCRIPT_DIR}/.demo-state/resources.tsv"
readonly PROJECT_PREFIX="${PROJECT_PREFIX:-tf-importer-demo}"
failures=0; deleted=0; skipped=0
verified_stale_tagged=0

log() { printf '[demo-delete] %s\n' "$*"; }
die() { printf '[demo-delete] ERROR: %s\n' "$*" >&2; exit 1; }
aws_demo() { aws --no-cli-pager --region "$AWS_REGION" "$@"; }
state_value() { awk -F '\t' -v kind="$1" '$1 == kind { print $2 }' "$STATE_FILE"; }
mark_deleted() { deleted=$((deleted + 1)); }
not_found() { skipped=$((skipped + 1)); log "$1 already absent"; }

ec2_exists() {
    local kind="$1" id="$2" count filter command query
    case "$kind" in
        security_group) command='describe-security-groups'; filter='group-id'; query='length(SecurityGroups)' ;;
        network_acl) command='describe-network-acls'; filter='network-acl-id'; query='length(NetworkAcls)' ;;
        route_table) command='describe-route-tables'; filter='route-table-id'; query='length(RouteTables)' ;;
        subnet) command='describe-subnets'; filter='subnet-id'; query='length(Subnets)' ;;
        internet_gateway) command='describe-internet-gateways'; filter='internet-gateway-id'; query='length(InternetGateways)' ;;
        vpc) command='describe-vpcs'; filter='vpc-id'; query='length(Vpcs)' ;;
        *) return 2 ;;
    esac
    if ! count="$(aws_demo ec2 "$command" --filters "Name=${filter},Values=${id}" \
        --query "$query" --output text 2>/dev/null)"; then
        log "Unable to verify $kind $id"
        return 2
    fi
    [[ "$count" != 0 ]]
}

verify_tag() {
    local arn="$1" found
    found="$(aws_demo resourcegroupstaggingapi get-resources --resource-arn-list "$arn" \
        --query "ResourceTagMappingList[0].Tags[?Key=='Project'].Value | [0]" --output text 2>/dev/null || true)"
    [[ "$found" == "$PROJECT_PREFIX" ]] || die "Refusing untagged/mismatched resource: $arn"
}

recover_untagged_empty_bucket() {
    local bucket="$1" location object_count version_count public_block
    [[ "$bucket" =~ ^${PROJECT_PREFIX}-[a-z0-9]{10}$ ]] ||
        die "Refusing untagged bucket with unexpected name: $bucket"

    location="$(aws_demo s3api get-bucket-location --bucket "$bucket" \
        --query 'LocationConstraint' --output text)"
    [[ "$location" != None ]] || location=us-east-1
    [[ "$location" == "$AWS_REGION" ]] ||
        die "Refusing untagged bucket in unexpected region: $bucket"

    object_count="$(aws_demo s3api list-objects-v2 --bucket "$bucket" \
        --max-keys 1 --query 'KeyCount' --output text)"
    version_count="$(aws_demo s3api list-object-versions --bucket "$bucket" \
        --max-items 1 --output json |
        jq '[.Versions[]?, .DeleteMarkers[]?] | length')"
    [[ "$object_count" == 0 && "$version_count" == 0 ]] ||
        die "Refusing non-empty untagged bucket: $bucket"

    public_block="$(aws_demo s3api get-public-access-block --bucket "$bucket" \
        --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]' \
        --output text)"
    [[ "$public_block" == $'True\tTrue\tTrue\tTrue' ]] ||
        die "Refusing untagged bucket without the expected public-access block: $bucket"

    log "Recovering manifest-recorded empty bucket whose creation stopped before tagging: $bucket"
    aws_demo s3api put-bucket-tagging --bucket "$bucket" --tagging \
        "{\"TagSet\":[{\"Key\":\"Project\",\"Value\":\"${PROJECT_PREFIX}\"}]}"
}

confirm_scope() {
    command -v aws >/dev/null || die "AWS CLI is required"
    [[ -n "${AWS_REGION:-}" ]] || die "Set AWS_REGION explicitly"
    [[ -s "$STATE_FILE" ]] || die "No demo state file found; refusing pattern-based cleanup"
    local account principal answer recorded_account recorded_region recorded_prefix
    account="$(aws_demo sts get-caller-identity --query Account --output text)"
    principal="$(aws_demo sts get-caller-identity --query Arn --output text)"
    recorded_account="$(state_value meta_account)"
    recorded_region="$(state_value meta_region)"
    recorded_prefix="$(state_value meta_prefix)"
    [[ -n "$recorded_account" && "$account" == "$recorded_account" ]] || die "Active account does not match the creation manifest"
    [[ -n "$recorded_region" && "$AWS_REGION" == "$recorded_region" ]] || die "AWS_REGION does not match the creation manifest"
    [[ -n "$recorded_prefix" && "$PROJECT_PREFIX" == "$recorded_prefix" ]] || die "PROJECT_PREFIX does not match the creation manifest"
    printf 'AWS account: %s\nRegion: %s\nPrincipal: %s\nPrefix: %s\nExact recorded scope:\n' "$account" "$AWS_REGION" "$principal" "$PROJECT_PREFIX"
    sed 's/^/  /' "$STATE_FILE"
    read -r -p 'Type DELETE to continue: ' answer
    [[ "$answer" == DELETE ]] || die "Cleanup cancelled"
}

delete_services() {
    local value arn bus rule cluster_status
    value="$(state_value event_rule)"; if [[ -n "$value" ]]; then
        bus="${value%%/*}"
        rule="${value#*/}"
        arn="arn:aws:events:${AWS_REGION}:$(aws_demo sts get-caller-identity --query Account --output text):rule/${value}"
        if ! aws_demo events describe-event-bus --name "$bus" >/dev/null 2>&1; then
            not_found "$value"
        elif [[ "$(aws_demo events list-rules --event-bus-name "$bus" --name-prefix "$rule" --query "length(Rules[?Name=='${rule}'])" --output text)" == 0 ]]; then
            not_found "$value"
        else
            verify_tag "$arn"
            if aws_demo events delete-rule --event-bus-name "$bus" --name "$rule"; then mark_deleted; else failures=$((failures + 1)); fi
        fi
    fi
    value="$(state_value event_bus)"; if [[ -n "$value" ]]; then
        if ! aws_demo events describe-event-bus --name "$value" >/dev/null 2>&1; then
            not_found "$value"
        else
            arn="arn:aws:events:${AWS_REGION}:$(aws_demo sts get-caller-identity --query Account --output text):event-bus/${value}"; verify_tag "$arn"
            aws_demo events delete-event-bus --name "$value" && mark_deleted || failures=$((failures + 1))
        fi
    fi
    value="$(state_value ecs_cluster)"; if [[ -n "$value" ]]; then
        arn="$(aws_demo ecs describe-clusters --clusters "$value" --query 'clusters[0].clusterArn' --output text)"
        if [[ "$arn" == None ]]; then
            not_found "$value"
        else
            cluster_status="$(aws_demo ecs describe-clusters --clusters "$value" --query 'clusters[0].status' --output text)"
            if [[ "$cluster_status" == INACTIVE ]]; then
                aws_demo ecs untag-resource --resource-arn "$arn" --tag-keys \
                    Project Environment ManagedBy Purpose Owner >/dev/null 2>&1 || true
                not_found "$value"
            else
                verify_tag "$arn"
                if aws_demo ecs delete-cluster --cluster "$value" >/dev/null; then
                    mark_deleted
                    aws_demo ecs untag-resource --resource-arn "$arn" --tag-keys \
                        Project Environment ManagedBy Purpose Owner >/dev/null 2>&1 || true
                else
                    failures=$((failures + 1))
                fi
            fi
        fi
    fi
    value="$(state_value log_group)"; if [[ -n "$value" ]]; then
        if [[ "$(aws_demo logs describe-log-groups --log-group-name-prefix "$value" --query "length(logGroups[?logGroupName=='${value}'])" --output text)" == 0 ]]; then
            not_found "$value"
        else
            arn="arn:aws:logs:${AWS_REGION}:$(aws_demo sts get-caller-identity --query Account --output text):log-group:${value}"; verify_tag "$arn"
            aws_demo logs delete-log-group --log-group-name "$value" && mark_deleted || failures=$((failures + 1))
        fi
    fi
    value="$(state_value ssm_parameter)"; if [[ -n "$value" ]]; then
        if [[ "$(aws_demo ssm describe-parameters --parameter-filters "Key=Name,Option=Equals,Values=${value}" --query 'length(Parameters)' --output text)" == 0 ]]; then
            not_found "$value"
        else
            arn="arn:aws:ssm:${AWS_REGION}:$(aws_demo sts get-caller-identity --query Account --output text):parameter${value}"; verify_tag "$arn"
            aws_demo ssm delete-parameter --name "$value" && mark_deleted || failures=$((failures + 1))
        fi
    fi
    value="$(state_value s3_bucket)"; if [[ -n "$value" ]]; then
        local project_tag
        if [[ "$(aws_demo s3api list-buckets --query "length(Buckets[?Name=='${value}'])" --output text)" == 0 ]]; then
            not_found "$value"
            return
        fi
        project_tag="$(aws_demo s3api get-bucket-tagging --bucket "$value" --query "TagSet[?Key=='Project'].Value | [0]" --output text 2>/dev/null || true)"
        if [[ -z "$project_tag" || "$project_tag" == None ]]; then
            recover_untagged_empty_bucket "$value"
            project_tag="$(aws_demo s3api get-bucket-tagging --bucket "$value" --query "TagSet[?Key=='Project'].Value | [0]" --output text)"
        fi
        [[ "$project_tag" == "$PROJECT_PREFIX" ]] || die "Refusing bucket with mismatched/missing tag: $value"
        aws_demo s3api delete-bucket --bucket "$value" && mark_deleted || failures=$((failures + 1))
    fi
}

delete_network() {
    local vpc value association
    vpc="$(state_value vpc)"
    if [[ -n "$vpc" ]]; then
        if ec2_exists vpc "$vpc"; then
            :
        elif [[ "$?" -eq 1 ]]; then
            not_found "$vpc"
            return
        else
            die "Unable to verify the manifest-recorded VPC before cleanup"
        fi
    fi
    [[ -z "$vpc" ]] || verify_tag "arn:aws:ec2:${AWS_REGION}:$(aws_demo sts get-caller-identity --query Account --output text):vpc/${vpc}"
    while IFS= read -r association; do
        [[ -z "$association" ]] && continue
        if [[ "$(aws_demo ec2 describe-route-tables --filters "Name=association.route-table-association-id,Values=${association}" --query 'length(RouteTables)' --output text)" == 0 ]]; then
            not_found "$association"
        elif aws_demo ec2 disassociate-route-table --association-id "$association"; then mark_deleted; else failures=$((failures + 1)); fi
    done < <(state_value route_table_association)
    value="$(state_value security_group)"; if [[ -n "$value" ]]; then
        if ec2_exists security_group "$value"; then
            verify_tag "arn:aws:ec2:${AWS_REGION}:$(aws_demo sts get-caller-identity --query Account --output text):security-group/${value}"
            if aws_demo ec2 delete-security-group --group-id "$value"; then mark_deleted; else failures=$((failures + 1)); fi
        elif [[ "$?" -eq 1 ]]; then
            not_found "$value"
        else
            failures=$((failures + 1))
        fi
    fi
    for kind in network_acl route_table subnet; do
        while IFS= read -r value; do
            [[ -z "$value" ]] && continue
            if ec2_exists "$kind" "$value"; then
                verify_tag "arn:aws:ec2:${AWS_REGION}:$(aws_demo sts get-caller-identity --query Account --output text):${kind//_/-}/${value}"
                aws_demo ec2 "delete-${kind//_/-}" "--${kind//_/-}-id" "$value" && mark_deleted || failures=$((failures + 1))
            elif [[ "$?" -eq 1 ]]; then
                not_found "$value"
            else
                failures=$((failures + 1))
            fi
        done < <(state_value "$kind")
    done
    value="$(state_value internet_gateway)"; if [[ -n "$value" ]]; then
        if ec2_exists internet_gateway "$value"; then
            :
        elif [[ "$?" -eq 1 ]]; then
            not_found "$value"; value=''
        else
            failures=$((failures + 1)); value=''
        fi
    fi
    if [[ -n "$value" ]]; then
        verify_tag "arn:aws:ec2:${AWS_REGION}:$(aws_demo sts get-caller-identity --query Account --output text):internet-gateway/${value}"
        aws_demo ec2 detach-internet-gateway --internet-gateway-id "$value" --vpc-id "$vpc" || failures=$((failures + 1))
        aws_demo ec2 delete-internet-gateway --internet-gateway-id "$value" && mark_deleted || failures=$((failures + 1))
    fi
    if [[ -n "$vpc" ]]; then
        aws_demo ec2 delete-vpc --vpc-id "$vpc" && mark_deleted || failures=$((failures + 1))
    fi
}

remaining_exact_resources() {
    local remaining=0 value
    value="$(state_value s3_bucket)"
    if [[ -n "$value" && "$(aws_demo s3api list-buckets --query "length(Buckets[?Name=='${value}'])" --output text)" != 0 ]]; then
        log "Still present: s3_bucket $value"; remaining=$((remaining + 1))
    fi
    value="$(state_value ssm_parameter)"
    if [[ -n "$value" && "$(aws_demo ssm describe-parameters --parameter-filters "Key=Name,Option=Equals,Values=${value}" --query 'length(Parameters)' --output text)" != 0 ]]; then
        log "Still present: ssm_parameter $value"; remaining=$((remaining + 1))
    fi
    value="$(state_value log_group)"
    if [[ -n "$value" && "$(aws_demo logs describe-log-groups --log-group-name-prefix "$value" --query "length(logGroups[?logGroupName=='${value}'])" --output text)" != 0 ]]; then
        log "Still present: log_group $value"; remaining=$((remaining + 1))
    fi
    value="$(state_value event_bus)"
    if [[ -n "$value" ]] && aws_demo events describe-event-bus --name "$value" >/dev/null 2>&1; then
        log "Still present: event_bus $value"; remaining=$((remaining + 1))
    fi
    value="$(state_value ecs_cluster)"
    if [[ -n "$value" && "$(aws_demo ecs describe-clusters --clusters "$value" --query "length(clusters[?status!='INACTIVE'])" --output text)" != 0 ]]; then
        log "Still present: ecs_cluster $value"; remaining=$((remaining + 1))
    fi
    for kind in security_group network_acl route_table subnet internet_gateway; do
        while IFS= read -r value; do
            [[ -z "$value" ]] && continue
            if ec2_exists "$kind" "$value"; then
                log "Still present: $kind $value"; remaining=$((remaining + 1))
            elif [[ "$?" -eq 2 ]]; then
                remaining=$((remaining + 1))
            fi
        done < <(state_value "$kind")
    done
    value="$(state_value vpc)"
    if [[ -n "$value" ]]; then
        if ec2_exists vpc "$value"; then
            log "Still present: vpc $value"; remaining=$((remaining + 1))
        elif [[ "$?" -eq 2 ]]; then
            remaining=$((remaining + 1))
        fi
    fi
    printf '%d\n' "$remaining"
}

remaining_named_demo_resources() {
    local remaining=0 count

    count="$(aws_demo s3api list-buckets \
        --query "length(Buckets[?starts_with(Name, '${PROJECT_PREFIX}-')])" \
        --output text)"
    if [[ "$count" != 0 ]]; then
        log "Still present: $count S3 bucket(s) with the demo prefix"
        remaining=$((remaining + count))
    fi

    count="$(aws_demo ssm describe-parameters \
        --parameter-filters "Key=Name,Option=Equals,Values=/${PROJECT_PREFIX}/message" \
        --query 'length(Parameters)' --output text)"
    if [[ "$count" != 0 ]]; then
        log "Still present: demo SSM parameter"
        remaining=$((remaining + count))
    fi

    count="$(aws_demo logs describe-log-groups \
        --log-group-name-prefix "/${PROJECT_PREFIX}/logs" \
        --query "length(logGroups[?logGroupName=='/${PROJECT_PREFIX}/logs'])" \
        --output text)"
    if [[ "$count" != 0 ]]; then
        log "Still present: demo CloudWatch log group"
        remaining=$((remaining + count))
    fi

    count="$(aws_demo events list-event-buses --name-prefix "${PROJECT_PREFIX}-bus" \
        --query "length(EventBuses[?Name=='${PROJECT_PREFIX}-bus'])" --output text)"
    if [[ "$count" != 0 ]]; then
        log "Still present: demo EventBridge bus"
        remaining=$((remaining + count))
    fi

    count="$(aws_demo ecs list-clusters \
        --query "length(clusterArns[?contains(@, '/${PROJECT_PREFIX}-cluster')])" \
        --output text)"
    if [[ "$count" != 0 ]]; then
        log "Still present: demo ECS cluster"
        remaining=$((remaining + count))
    fi

    printf '%d\n' "$remaining"
}

tagged_resource_counts() {
    local mappings active stale=0 cluster account arn response status
    mappings="$(aws_demo resourcegroupstaggingapi get-resources \
        --tag-filters Key=Project,Values="$PROJECT_PREFIX" --output json)"
    active="$(jq '.ResourceTagMappingList | length' <<< "$mappings")"

    cluster="$(state_value ecs_cluster)"
    account="$(state_value meta_account)"
    if [[ -n "$cluster" && -n "$account" ]]; then
        arn="arn:aws:ecs:${AWS_REGION}:${account}:cluster/${cluster}"
        if response="$(aws_demo ecs describe-clusters --clusters "$cluster" --output json 2>/dev/null)"; then
            status="$(jq -r '.clusters[0].status // "MISSING"' <<< "$response")"
            if [[ "$status" == INACTIVE || "$status" == MISSING ]]; then
                stale="$(jq --arg arn "$arn" \
                    '[.ResourceTagMappingList[] | select(.ResourceARN == $arn)] | length' \
                    <<< "$mappings")"
                active=$((active - stale))
            fi
        fi
    fi

    printf '%d %d\n' "$active" "$stale"
}

verify_cleanup() {
    local attempt remaining tagged named stale_tagged
    local max_attempts=18
    local retry_delay=10
    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        remaining="$(remaining_exact_resources | tail -n 1)"
        read -r tagged stale_tagged < <(tagged_resource_counts)
        named="$(remaining_named_demo_resources | tail -n 1)"
        if [[ "$remaining" == 0 && "$tagged" == 0 && "$named" == 0 ]]; then
            verified_stale_tagged="$stale_tagged"
            log "Post-cleanup verification passed on attempt $attempt (stale_tag_index_entries=$stale_tagged)"
            return 0
        fi
        log "Verification attempt $attempt: exact_remaining=$remaining tagged_active_remaining=$tagged named_remaining=$named stale_tag_index_entries=$stale_tagged"
        (( attempt == max_attempts )) || sleep "$retry_delay"
    done
    return 1
}

main() {
    confirm_scope; delete_services; delete_network
    printf 'Cleanup summary: deleted=%d already_absent=%d failures=%d\n' "$deleted" "$skipped" "$failures"
    if (( failures > 0 )); then die "Unexpected cleanup failures; state retained at $STATE_FILE"; fi
    if ! verify_cleanup; then die "Cleanup could not prove zero remaining resources; state retained at $STATE_FILE"; fi
    rm -f "$STATE_FILE"; rmdir "$(dirname "$STATE_FILE")" 2>/dev/null || true
    [[ ! -e "$STATE_FILE" ]] || die "Cleanup passed but the local manifest could not be removed"
    log "Verified: exact_remaining=0 tagged_active_remaining=0 named_remaining=0 stale_tag_index_entries=$verified_stale_tagged manifest=absent"
    log "Cleanup complete"
}
main "$@"

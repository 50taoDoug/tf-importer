#!/usr/bin/env bash

aws_resource_explorer_enabled_for_environment() {
    local environment="$1"
    local env_conf="${PROJECT_ROOT}/config/environments.conf"
    local configured

    if [[ -n "${TF_ACCOUNT_KEY:-}" ]]; then
        configured=$(terraform_get_account_field \
            "$TF_ACCOUNT_KEY" RESOURCE_EXPLORER 2>/dev/null || true)
        case "${configured,,}" in
            true|yes|1)
                return 0
                ;;
            false|no|0)
                return 1
                ;;
        esac
    fi

    configured=$(grep '^RESOURCE_EXPLORER_ENVIRONMENTS=' "$env_conf" 2>/dev/null \
        | cut -d'=' -f2- | tr -d '[:space:]')

    [[ -n "$configured" ]] || return 1
    tr ',' '\n' <<< "$configured" | grep -Fxq "$environment"
}

aws_resource_explorer_discover_region() {
    local region="${AWS_DISCOVER_REGION:?AWS_DISCOVER_REGION is not set}"
    local token=""
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local page_num=0

    log_info "Resource Explorer discovery starting - region: $region"

    while true; do
        local args=(resource-explorer-2 list-resources
            --region "$region"
            --filters "FilterString=region:$region"
            --output json)
        [[ -n "$token" ]] && args+=(--starting-token "$token")

        page_num=$((page_num + 1))
        local page_file="${tmp_dir}/page_${page_num}.json"
        log_debug "executing Resource Explorer discovery in region=$region"

        if ! aws "${args[@]}" > "$page_file"; then
            log_error "Resource Explorer discovery failed for region '$region'."
            rm -rf "$tmp_dir"
            return 1
        fi

        token=$(jq -r '.NextToken // empty' "$page_file")
        [[ -z "$token" ]] && break
    done

    jq -s --arg region "$region" '
        [.[].Resources[]?]
        | map({
            arn: .Arn,
            region: (.Region // $region),
            tags: {},
            sources: ["resource_explorer"],
            resource_type: (.ResourceType // null)
        })
        | sort_by(.arn)
    ' "${tmp_dir}"/page_*.json

    rm -rf "$tmp_dir"
}

aws_discover_environment() {
    local environment="$1"
    local tagging_file
    local explorer_file
    tagging_file=$(mktemp)
    explorer_file=$(mktemp)

    if [[ "$environment" == demo ]]; then
        AWS_DISCOVER_TAG_KEY=Project \
            AWS_DISCOVER_TAG_VALUE="${PROJECT_PREFIX:-tf-importer-demo}" \
            aws_generic_discover_region > "$tagging_file" || {
                rm -f "$tagging_file" "$explorer_file"
                return 1
            }
    elif ! aws_generic_discover_region > "$tagging_file"; then
        rm -f "$tagging_file" "$explorer_file"
        return 1
    fi

    if ! aws_resource_explorer_enabled_for_environment "$environment"; then
        cat "$tagging_file"
        rm -f "$tagging_file" "$explorer_file"
        return 0
    fi

    log_info "Resource Explorer enabled for environment '$environment'."
    if ! aws_resource_explorer_discover_region > "$explorer_file"; then
        rm -f "$tagging_file" "$explorer_file"
        return 1
    fi

    jq -s '
        map(.[])
        | group_by(.arn)
        | map(
            reduce .[] as $item ({};
                .arn = ($item.arn // .arn)
                | .region = ($item.region // .region)
                | .tags = ((.tags // {}) + ($item.tags // {}))
                | .sources = (((.sources // []) + ($item.sources // [])) | unique)
                | if (.resource_type // null) == null
                  then .resource_type = ($item.resource_type // null)
                  else .
                  end
            )
        )
        | sort_by(.arn)
    ' "$tagging_file" "$explorer_file"

    rm -f "$tagging_file" "$explorer_file"
}

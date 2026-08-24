#!/usr/bin/env bash

aws_generic_discover_region() {
    local region="${AWS_DISCOVER_REGION:?AWS_DISCOVER_REGION is not set}"
    local token=""
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local page_num=0

    log_info "Generic discovery starting (Resource Groups Tagging API) - region: $region"

    while true; do
        local args=(--region "$region" --output json)
        [[ -n "$token" ]] && args+=(--starting-token "$token")
        if [[ -n "${AWS_DISCOVER_TAG_KEY:-}" && -n "${AWS_DISCOVER_TAG_VALUE:-}" ]]; then
            args+=(--tag-filters \
                "Key=${AWS_DISCOVER_TAG_KEY},Values=${AWS_DISCOVER_TAG_VALUE}")
        fi

        page_num=$((page_num + 1))
        local page_file="${tmp_dir}/page_${page_num}.json"

        log_debug "executing discovery in region=$region"

        if ! aws resourcegroupstaggingapi get-resources "${args[@]}" \
            > "$page_file"; then

            log_error "Resource discovery failed for region '${region}'."

            rm -rf "$tmp_dir"
            return 1
        fi

        log_info "Discovery page $page_num received."

        token=$(jq -r '.PaginationToken // empty' "$page_file")

        [[ -z "$token" ]] && break
    done

    local total
    total=$(jq -s '[.[].ResourceTagMappingList[]] | length' "${tmp_dir}"/page_*.json)
    log_info "Generic discovery finished: $total resources found"

    jq -s --arg region "$region" '
        [.[].ResourceTagMappingList[]]
        | map({
            arn: .ResourceARN,
            region: $region,
            sources: ["resource_groups_tagging_api"],
            tags: (
                (.Tags // [])
                | map({(.Key): .Value})
                | add // {}
            )
        })
        | sort_by(.arn)
    ' "${tmp_dir}"/page_*.json

    rm -rf "$tmp_dir"
}

#!/usr/bin/env bash

terraform_sanitize_name() {
    local raw="$1"
    local safe
    safe=$(echo "$raw" | sed -E 's/[^a-zA-Z0-9_]/_/g')
    if [[ "$safe" =~ ^[0-9] ]]; then
        safe="r_${safe}"
    fi
    echo "$safe"
}

terraform_generate_import_blocks() {
    local discovery="${TF_OUTPUT_DIR}/discovery.json"
    local output="${TF_ENV_DIR}/imports_generated.tf"
    local unmapped="${TF_REPORTS_DIR}/unmapped_resources.json"
    local classification="${TF_REPORTS_DIR}/discovery_classification.json"
    local filtered_tmp
    filtered_tmp=$(mktemp)
    local classification_lines
    classification_lines=$(mktemp)

    mkdir -p "$(dirname "$output")" "$(dirname "$unmapped")" \
        "$(dirname "$classification")"

    log_info "Filtering excluded resources..."
    terraform_filter_excluded "$discovery" > "$filtered_tmp"
    jq -c --slurpfile patterns \
        "${PROJECT_ROOT}/config/exclude_patterns.json" '
        .[] as $resource
        | (
            $patterns[0]
            | map(
                select(
                    .pattern as $pattern
                    | $resource.arn
                    | test($pattern)
                )
            )
            | first
        ) as $matched
        | select($matched != null)
        | {
            arn: $resource.arn,
            service: ($resource.arn | split(":")[2]),
            sources: ($resource.sources // ["resource_groups_tagging_api"]),
            classification: "excluded_by_policy",
            action: "excluded_from_terraform_generation",
            reason: $matched.reason,
            matched_pattern: $matched.pattern,
            terraform_targets: []
        }
    ' "$discovery" > "$classification_lines"

    log_info "Checking ENI interface types..."
    local bad_enis
    if ! bad_enis=$(aws_get_bad_eni_ids "$filtered_tmp"); then
        log_error "Unable to classify ENI interface types."
        rm -f "$filtered_tmp" "$classification_lines"
        return 1
    fi
    local bad_eni_count
    bad_eni_count=$(echo "$bad_enis" | grep -c . || true)
    log_info "Non-importable ENIs found: $bad_eni_count"

    log_info "Checking default Network ACLs..."
    local default_nacls
    default_nacls=$(aws_get_default_nacl_ids)
    local default_nacl_count
    default_nacl_count=$(echo "$default_nacls" | tr '\t' '\n' | grep -c . || true)
    log_info "Default network ACLs found: $default_nacl_count"

    local total_filtered
    total_filtered=$(jq 'length' "$filtered_tmp")
    log_info "Resources after exclusion: $total_filtered"

    > "$output"
    echo "[]" > "$unmapped"

    declare -A used_names
    local count_mapped=0
    local count_unmapped=0
    local count_controller_managed=0
    local count_represented_by_parent=0
    local count_eni_skipped=0
    local count_ephemeral_skipped=0
    local count_nacl_skipped=0

    local arns
    arns=$(jq -r '.[].arn' "$filtered_tmp")

    while read -r arn; do
        [[ -z "$arn" ]] && continue

        local sources_json
        sources_json=$(jq -c --arg arn "$arn" \
            'first(.[] | select(.arn == $arn) |
                (.sources // ["resource_groups_tagging_api"]))' \
            "$filtered_tmp")

        local resource_type
        resource_type=$(jq -r --arg arn "$arn" '
            first(.[] | select(.arn == $arn) | (.resource_type // ""))
        ' "$filtered_tmp")

        if [[ "$resource_type" == "ec2:security-group-rule" ]]; then
            jq -cn \
                --arg arn "$arn" \
                --argjson sources "$sources_json" \
                '{
                    arn: $arn,
                    service: ($arn | split(":")[2]),
                    sources: $sources,
                    classification: "represented_by_parent",
                    action: "represented_by_security_group",
                    reason: "Rule is preserved inline in the imported aws_security_group ingress or egress configuration.",
                    terraform_targets: []
                }' >> "$classification_lines"
            count_represented_by_parent=$((count_represented_by_parent + 1))
            continue
        fi

        case "$resource_type" in
            rds:snapshot|rds:auto-backup|ec2:spot-instances-request|ssm:managed-instance)
                jq -cn \
                    --arg arn "$arn" \
                    --argjson sources "$sources_json" \
                    '{
                        arn: $arn,
                        service: ($arn | split(":")[2]),
                        sources: $sources,
                        classification: "skipped_non_importable",
                        action: "skipped_as_ephemeral",
                        reason: "Ephemeral or service-generated inventory object is retained in the audit report and not imported.",
                        terraform_targets: []
                    }' >> "$classification_lines"
                count_ephemeral_skipped=$((count_ephemeral_skipped + 1))
                continue
                ;;
        esac

        local controller_reason
        controller_reason=$(jq -r --arg arn "$arn" '
            first(.[] | select(.arn == $arn) |
                if (.resource_type == "ec2:instance" and
                    (((.tags // {}) | to_entries |
                      map((.key + "=" + (.value | tostring))) |
                      join("\n")) |
                     test("karpenter|kubernetes\\.io/cluster/|aws:eks:cluster-name|eks:nodegroup-name|aws:autoscaling:groupName"; "i")))
                then "EC2 node is managed by the EKS/Karpenter controller."
                elif (.resource_type == "ec2:network-interface" and
                      (((.tags // {})["eks:eni:owner"] // "") == "amazon-vpc-cni" or
                       ((.tags // {}) | has("eks:eks-cluster-name")) or
                       ((.tags // {}) | keys |
                        any(startswith("kubernetes.io/cluster/")))))
                then "Network interface is managed by the Amazon VPC CNI controller."
                elif (($arn | split(":")[2]) == "elasticloadbalancing" and
                      ((.tags // {}) | has("kubernetes.io/service-name")) and
                      ((.tags // {}) | keys |
                       any(startswith("kubernetes.io/cluster/"))))
                then "Load balancer resource is managed by a Kubernetes Service controller."
                elif ($arn | test(":eks:[^:]+:[^:]+:(pod|replicaset|service|endpointslice|namespace|deployment|daemonset|persistentvolume|statefulset|ingress)/"))
                then "Kubernetes object is managed by the EKS cluster control plane."
                else ""
                end)
        ' "$filtered_tmp")
        if [[ -n "$controller_reason" ]]; then
            jq -cn \
                --arg arn "$arn" \
                --argjson sources "$sources_json" \
                --arg reason "$controller_reason" \
                '{
                    arn: $arn,
                    service: ($arn | split(":")[2]),
                    sources: $sources,
                    classification: "controller_managed",
                    action: "managed_by_controller",
                    reason: $reason,
                    terraform_targets: []
                }' >> "$classification_lines"
            count_controller_managed=$((count_controller_managed + 1))
            continue
        fi

        if [[ "$arn" == *":network-interface/"* ]]; then
            local eni_id
            eni_id=$(echo "$arn" | sed -E 's#.*:network-interface/##')
            if echo "$bad_enis" | grep -qx "$eni_id"; then
                jq -cn \
                    --arg arn "$arn" \
                    --argjson sources "$sources_json" \
                    '{
                        arn: $arn,
                        service: ($arn | split(":")[2]),
                        sources: $sources,
                        classification: "skipped_non_importable",
                        action: "skipped_as_non_importable",
                        reason: "ENI interface type cannot be imported independently, or the discovered ENI no longer exists.",
                        terraform_targets: []
                    }' >> "$classification_lines"
                count_eni_skipped=$((count_eni_skipped + 1))
                continue
            fi
        fi

        if [[ "$arn" == *":event-bus/default" ]]; then
            jq -cn \
                --arg arn "$arn" \
                --argjson sources "$sources_json" \
                ' {
                    arn: $arn,
                    service: ($arn | split(":")[2]),
                    sources: $sources,
                    classification: "skipped_non_importable",
                    action: "skipped_as_non_importable",
                    reason: "AWS-managed default EventBridge bus cannot be represented as an aws_cloudwatch_event_bus resource.",
                    terraform_targets: []
                }' >> "$classification_lines"
            continue
        fi

        local types
        types=$(terraform_map_arn_to_type "$arn")

        if [[ -z "$types" ]]; then
            jq --arg arn "$arn" '. += [$arn]' "$unmapped" > "${unmapped}.tmp" && mv "${unmapped}.tmp" "$unmapped"
            jq -cn \
                --arg arn "$arn" \
                --argjson sources "$sources_json" \
                '{
                    arn: $arn,
                    service: ($arn | split(":")[2]),
                    sources: $sources,
                    classification: "unmapped",
                    action: "left_unmapped",
                    reason: "No ARN-to-Terraform mapping is configured.",
                    terraform_targets: []
                }' >> "$classification_lines"
            count_unmapped=$((count_unmapped + 1))
            continue
        fi

        local mapping_adjustment=""
        if [[ "$arn" == *":network-acl/"* ]]; then
            local nacl_id
            nacl_id=$(echo "$arn" | sed -E 's#.*:network-acl/##')
            if echo "$default_nacls" | tr '\t' '\n' | grep -qx "$nacl_id"; then
                types="aws_default_network_acl"
                mapping_adjustment="Default Network ACL uses aws_default_network_acl."
                count_nacl_skipped=$((count_nacl_skipped + 1))
            fi
        fi

        local targets_json="[]"
        for tf_type in $types; do
            local id
            id=$(terraform_extract_id "$arn" "$tf_type")

            local base_name
            base_name=$(terraform_sanitize_name "$id")

            local final_name="$base_name"
            local suffix=1
            while [[ -n "${used_names[$final_name]:-}" ]]; do
                final_name="${base_name}_${suffix}"
                suffix=$((suffix + 1))
            done
            used_names["$final_name"]=1

            cat >> "$output" <<EOF2

import {
  to = ${tf_type}.${final_name}
  id = "${id}"
}
EOF2
            targets_json=$(jq -cn \
                --argjson targets "$targets_json" \
                --arg type "$tf_type" \
                --arg address "${tf_type}.${final_name}" \
                --arg id "$id" \
                '$targets + [{
                    terraform_type: $type,
                    address: $address,
                    import_id: $id
                }]')
            count_mapped=$((count_mapped + 1))
        done

        jq -cn \
            --arg arn "$arn" \
            --arg adjustment "$mapping_adjustment" \
            --argjson sources "$sources_json" \
            --argjson targets "$targets_json" \
            '{
                arn: $arn,
                service: ($arn | split(":")[2]),
                sources: $sources,
                classification: "mapped_import_candidate",
                action: "candidate_for_import",
                reason: "ARN mapped to one or more Terraform import targets.",
                terraform_targets: $targets
            }
            + if $adjustment == "" then {}
              else {mapping_adjustment: $adjustment}
              end' >> "$classification_lines"
    done <<< "$arns"

    local environment
    environment=$(basename "$TF_ENV_DIR")
    local project_name
    project_name=$(terraform_get_project_name)
    local env_upper
    env_upper=$(printf '%s' "$environment" | tr '[:lower:]' '[:upper:]')
    local account_id
    if [[ -n "${TF_ACCOUNT_KEY:-}" ]]; then
        account_id=$(terraform_get_account_field "$TF_ACCOUNT_KEY" ID)
    else
        account_id=$(grep "^${env_upper}_ACCOUNT_ID=" \
            "${PROJECT_ROOT}/config/environments.conf" |
            cut -d'=' -f2 | tr -d '[:space:]')
    fi
    local discovered_count
    discovered_count=$(jq 'length' "$discovery")

    jq -s \
        --arg project "$project_name" \
        --arg environment "$environment" \
        --arg region "$TF_REGION" \
        --arg account_id "$account_id" \
        --argjson discovered "$discovered_count" \
        'sort_by(.arn)
         | {
             schema_version: 1,
             project: $project,
             environment: $environment,
             region: $region,
             account_id: $account_id,
             summary: {
                 discovered_resources: $discovered,
                 classified_resources: length,
                 excluded_by_policy: (
                     map(select(.classification == "excluded_by_policy"))
                     | length
                 ),
                 skipped_non_importable: (
                     map(select(.classification == "skipped_non_importable"))
                     | length
                 ),
                 unmapped_resources: (
                     map(select(.classification == "unmapped"))
                     | length
                 ),
                 represented_by_parent_resources: (
                     map(select(.classification == "represented_by_parent"))
                     | length
                 ),
                 controller_managed_resources: (
                     map(select(.classification == "controller_managed"))
                     | length
                 ),
                 mapped_resources: (
                     map(select(.classification == "mapped_import_candidate"))
                     | length
                 ),
                 generated_import_candidates: (
                     map(.terraform_targets | length) | add // 0
                 )
             },
             resources: .
         }
         | if .summary.discovered_resources
              != .summary.classified_resources
           then error("Discovery classification does not reconcile")
           else .
           end' \
        "$classification_lines" > "$classification" || {
            rm -f "$filtered_tmp" "$classification_lines"
            return 1
        }

    rm -f "$filtered_tmp" "$classification_lines"

    log_info "Import blocks generated: $count_mapped"
    log_info "ENIs skipped: $count_eni_skipped"
    log_info "Default network ACLs imported as aws_default_network_acl: $count_nacl_skipped"
    log_info "Unmapped resources: $count_unmapped (see $unmapped)"
    log_info "Resources represented by a parent Terraform resource: $count_represented_by_parent"
    log_info "Controller-managed resources: $count_controller_managed"
    log_info "Ephemeral resources skipped: $count_ephemeral_skipped"
    log_info "Discovery classification: $classification"
    log_info "Output file: $output"
}

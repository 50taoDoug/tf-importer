#!/usr/bin/env bash

aws_get_bad_eni_ids() {
    local discovery="$1"
    local region="${AWS_DISCOVER_REGION:?AWS_DISCOVER_REGION is not set}"
    local -a eni_ids=()
    local response
    local error_file
    error_file=$(mktemp)

    mapfile -t eni_ids < <(
        jq -r '.[].arn' "$discovery" |
            grep ':network-interface/' |
            sed -E 's#.*:network-interface/##'
    )

    if [[ ${#eni_ids[@]} -eq 0 ]]; then
        rm -f "$error_file"
        return 0
    fi

    if response=$(aws ec2 describe-network-interfaces \
        --region "$region" \
        --network-interface-ids "${eni_ids[@]}" \
        --output json 2>"$error_file"); then
        jq -r '
            .NetworkInterfaces[]
            | select(.InterfaceType as $t | ["interface","efa","efa-only","branch","trunk"] | index($t) | not)
            | .NetworkInterfaceId
        ' <<< "$response"
        rm -f "$error_file"
        return 0
    fi

    if ! grep -q "InvalidNetworkInterfaceID.NotFound" "$error_file"; then
        cat "$error_file" >&2
        rm -f "$error_file"
        return 1
    fi

    local eni_id
    for eni_id in "${eni_ids[@]}"; do
        if response=$(aws ec2 describe-network-interfaces \
            --region "$region" \
            --network-interface-ids "$eni_id" \
            --output json 2>"$error_file"); then
            jq -r '
                .NetworkInterfaces[]
                | select(.InterfaceType as $t | ["interface","efa","efa-only","branch","trunk"] | index($t) | not)
                | .NetworkInterfaceId
            ' <<< "$response"
        elif grep -q "InvalidNetworkInterfaceID.NotFound" "$error_file"; then
            echo "$eni_id"
        else
            cat "$error_file" >&2
            rm -f "$error_file"
            return 1
        fi
    done

    rm -f "$error_file"
}

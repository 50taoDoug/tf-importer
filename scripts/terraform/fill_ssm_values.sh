#!/usr/bin/env bash

terraform_fill_ssm_values() {
    local file="${TF_ENV_DIR}/auto_generated.tf"
    local region="${AWS_DISCOVER_REGION:?AWS_DISCOVER_REGION is not set}"
    local report="${TF_REPORTS_DIR}/ssm_fill_failures.json"
    echo "[]" > "$report"

    local names
    names=$(awk '
        /^resource "aws_ssm_parameter"/ { inblock=1 }
        inblock && /^\s*name\s*=/ {
            match($0, /"[^"]+"/)
            print substr($0, RSTART+1, RLENGTH-2)
            inblock=0
        }
    ' "$file")

    local count_ok=0
    local count_fail=0

    while read -r pname; do
        [[ -z "$pname" ]] && continue

        local value
        value=$(aws ssm get-parameter --region "$region" --name "$pname" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null)

        if [[ -z "$value" || "$value" == "None" ]]; then
            jq --arg n "$pname" '. += [$n]' "$report" > "${report}.tmp" && mv "${report}.tmp" "$report"
            count_fail=$((count_fail + 1))
            continue
        fi

        local escaped_value
        escaped_value=$(printf '%s' "$value" | sed 's/\\/\\\\/g; s/"/\\"/g')

        awk -v pname="$pname" -v newval="$escaped_value" '
            BEGIN { inblock=0 }
            /^resource "aws_ssm_parameter"/ { inblock=0 }
            {
                if ($0 ~ /^\s*name\s*=/) {
                    match($0, /"[^"]+"/)
                    bn = substr($0, RSTART+1, RLENGTH-2)
                    inblock = (bn == pname)
                }
                if (inblock && $0 ~ /^\s*value\s*=\s*null/) {
                    sub(/value\s*=\s*null.*/, "value            = \"" newval "\"")
                }
                if (inblock && $0 ~ /^\s*value_wo\s*=\s*null/) {
                    next
                }
                print
            }
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"

        count_ok=$((count_ok + 1))
    done <<< "$names"

    log_info "SSM parameters populated: $count_ok"
    log_info "SSM parameter failures: $count_fail (see $report)"
}

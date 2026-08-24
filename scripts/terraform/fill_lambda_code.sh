#!/usr/bin/env bash

terraform_fill_lambda_code() {
    local file="${TF_ENV_DIR}/auto_generated.tf"
    local region="${AWS_DISCOVER_REGION:?AWS_DISCOVER_REGION is not set}"
    local code_dir="${TF_ENV_DIR}/lambda_code"
    local report="${TF_REPORTS_DIR}/lambda_fill_failures.json"

    mkdir -p "$code_dir"
    echo "[]" > "$report"

    local names
    names=$(awk '
        /^resource "aws_lambda_function"/ { inblock=1 }
        inblock && /^\s*function_name\s*=/ {
            match($0, /"[^"]+"/)
            print substr($0, RSTART+1, RLENGTH-2)
            inblock=0
        }
    ' "$file")

    local count_ok=0
    local count_fail=0

    while read -r fname; do
        [[ -z "$fname" ]] && continue

        local url
        url=$(aws lambda get-function --region "$region" --function-name "$fname" --query 'Code.Location' --output text 2>/dev/null)

        if [[ -z "$url" || "$url" == "None" ]]; then
            jq --arg n "$fname" '. += [$n]' "$report" > "${report}.tmp" && mv "${report}.tmp" "$report"
            count_fail=$((count_fail + 1))
            continue
        fi

        local safe_name
        safe_name=$(echo "$fname" | sed -E 's/[^a-zA-Z0-9_]/_/g')
        local zip_path="${code_dir}/${safe_name}.zip"

        curl -sL -o "$zip_path" "$url"

        if [[ ! -s "$zip_path" ]]; then
            jq --arg n "$fname" '. += [$n]' "$report" > "${report}.tmp" && mv "${report}.tmp" "$report"
            count_fail=$((count_fail + 1))
            continue
        fi

        awk -v fname="$fname" -v zpath="./lambda_code/${safe_name}.zip" '
            BEGIN { capturing=0; buffer=""; match_found=0 }
            /^resource "aws_lambda_function"/ { capturing=1; buffer=$0"\n"; match_found=0; next }
            capturing {
                buffer = buffer $0 "\n"
                if ($0 ~ /^\s*function_name\s*=/) {
                    line=$0
                    match(line, /"[^"]+"/)
                    bn = substr(line, RSTART+1, RLENGTH-2)
                    if (bn == fname) match_found=1
                }
                if ($0 ~ /^\}/) {
                    if (match_found) {
                        gsub(/filename[ \t]*=[ \t]*null[^\n]*/, "filename                           = \"" zpath "\"", buffer)
                        gsub(/image_uri[ \t]*=[ \t]*null[^\n]*\n/, "", buffer)
                        gsub(/s3_bucket[ \t]*=[ \t]*null[^\n]*\n/, "", buffer)
                    }
                    printf "%s", buffer
                    capturing=0; buffer=""
                    next
                }
                next
            }
            { print }
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"

        count_ok=$((count_ok + 1))
    done <<< "$names"

    log_info "Lambda function packages downloaded: $count_ok"
    log_info "Lambda function download failures: $count_fail (see $report)"
}

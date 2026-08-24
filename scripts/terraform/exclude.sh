#!/usr/bin/env bash

terraform_filter_excluded() {
    local input_file="$1"
    local exclude_file="${PROJECT_ROOT}/config/exclude_patterns.json"

    jq --slurpfile patterns "$exclude_file" '
        def is_excluded($arn):
            any($patterns[0][]; . as $p | $arn | test($p.pattern));

        map(select(is_excluded(.arn) | not))
    ' "$input_file"
}

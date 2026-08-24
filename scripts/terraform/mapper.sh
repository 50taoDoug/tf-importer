#!/usr/bin/env bash

terraform_map_arn_to_type() {
    local arn="$1"
    local map_file="${PROJECT_ROOT}/config/resource_type_map.json"

    jq -r --slurpfile map "$map_file" -n --arg arn "$arn" '
        $map[0][]
        | . as $entry
        | select($arn | test($entry.pattern))
        | $entry.types[]
    '
}

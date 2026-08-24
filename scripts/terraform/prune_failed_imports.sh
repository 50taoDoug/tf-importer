#!/usr/bin/env bash

_strip_resource_block() {
    local file="$1"
    local rtype="$2"
    local rname="$3"
    awk -v rtype="$rtype" -v rname="$rname" '
        BEGIN { depth=0; skipping=0 }
        {
            if (!skipping && $0 ~ ("^resource \"" rtype "\" \"" rname "\" \\{")) {
                skipping=1; depth=1; next
            }
            if (skipping) {
                n_open=gsub(/\{/,"{")
                n_close=gsub(/\}/,"}")
                depth += n_open - n_close
                if (depth <= 0) { skipping=0 }
                next
            }
            print
        }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

terraform_prune_failed_imports() {
    local plan_log="$1"
    local imports_file="${TF_ENV_DIR}/imports_generated.tf"
    local config_file="${TF_ENV_DIR}/auto_generated.tf"
    local pruned_report="${TF_REPORTS_DIR}/pruned_imports.json"

    mkdir -p "$(dirname "$pruned_report")"
    if ! jq -e 'type == "array"' "$pruned_report" >/dev/null 2>&1; then
        echo "[]" > "$pruned_report"
    fi

    local failed_addresses
    failed_addresses=$(grep -A 3 "Cannot import non-existent remote object" "$plan_log" \
        | grep -oE '"[a-zA-Z0-9_]+\.[A-Za-z0-9_]+"' \
        | tr -d '"' \
        | sort -u) || true

    if [[ -z "$failed_addresses" ]]; then
        log_info "No failed imports found in the log."
        return 0
    fi

    local count=0

    while read -r addr; do
        [[ -z "$addr" ]] && continue

        local target="to = ${addr}"

        if grep -qxF "  ${target}" "$imports_file" || grep -qxF "${target}" "$imports_file"; then
            awk -v target="$target" '
                BEGIN { capturing=0; buffer=""; matched=0 }
                /^import \{/ { capturing=1; buffer=$0"\n"; matched=0; next }
                capturing {
                    line=$0
                    gsub(/^[ \t]+|[ \t]+$/, "", line)
                    if (line == target) matched=1
                    buffer = buffer $0 "\n"
                    if ($0 ~ /^\}/) {
                        if (!matched) printf "%s", buffer
                        capturing=0; buffer=""; next
                    }
                    next
                }
                { print }
            ' "$imports_file" > "${imports_file}.tmp" && mv "${imports_file}.tmp" "$imports_file"

            # Also remove the corresponding resource block.
            local rtype="${addr%%.*}"
            local rname="${addr#*.}"
            _strip_resource_block "$config_file" "$rtype" "$rname"

            jq --arg addr "$addr" '. + [$addr] | unique' \
                "$pruned_report" > "${pruned_report}.tmp" &&
                mv "${pruned_report}.tmp" "$pruned_report"
            count=$((count + 1))
        fi
    done <<< "$failed_addresses"

    log_info "Import blocks removed: $count (also removed from auto_generated.tf)"
}

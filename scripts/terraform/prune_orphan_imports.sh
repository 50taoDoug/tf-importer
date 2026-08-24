#!/usr/bin/env bash

terraform_prune_orphan_imports() {
    local imports_file="${TF_ENV_DIR}/imports_generated.tf"
    local config_file="${TF_ENV_DIR}/auto_generated.tf"
    local report="${TF_REPORTS_DIR}/orphan_imports.json"
    local valid_file
    valid_file=$(mktemp)
    local current_report
    current_report=$(mktemp)

    if ! jq -e 'type == "array"' "$report" >/dev/null 2>&1; then
        echo "[]" > "$report"
    fi

    grep -oE '^resource "[a-zA-Z0-9_]+" "[A-Za-z0-9_]+"' "$config_file" \
        | sed -E 's/^resource "([a-zA-Z0-9_]+)" "([A-Za-z0-9_]+)"/\1.\2/' \
        | sort -u > "$valid_file"

    awk -v valid_file="$valid_file" -v report="$current_report" '
        BEGIN {
            while ((getline line < valid_file) > 0) valid[line] = 1
            print "[" > report
            first = 1
        }
        /^import \{/ { capturing=1; buffer=$0"\n"; addr=""; next }
        capturing {
            buffer = buffer $0 "\n"
            if ($0 ~ /^[ \t]*to[ \t]*=/) {
                line=$0
                sub(/^[ \t]*to[ \t]*=[ \t]*/, "", line)
                gsub(/[ \t]*$/, "", line)
                addr = line
            }
            if ($0 ~ /^\}/) {
                if (addr in valid) {
                    printf "%s", buffer
                } else {
                    if (!first) print "," > report
                    printf "  \"%s\"", addr > report
                    first = 0
                }
                capturing=0; buffer=""; next
            }
            next
        }
        { print }
        END { print "]" > report }
    ' "$imports_file" > "${imports_file}.tmp"

    mv "${imports_file}.tmp" "$imports_file"
    rm -f "$valid_file"

    jq -s 'add | unique' "$report" "$current_report" > "${report}.tmp" &&
        mv "${report}.tmp" "$report"
    rm -f "$current_report"

    local count
    count=$(jq "length" "$report" 2>/dev/null || echo "?")
    log_info "Orphan imports removed because no configuration was generated: $count (see $report)"
}

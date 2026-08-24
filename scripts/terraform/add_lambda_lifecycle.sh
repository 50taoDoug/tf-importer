#!/usr/bin/env bash

terraform_add_lambda_lifecycle() {
    local file="${TF_ENV_DIR}/auto_generated.tf"
    local backup="${file}.bak.$(date +%s)"

    cp "$file" "$backup"
    log_info "Backup saved to: $backup"

    awk '
        BEGIN { depth=0; inblock=0 }
        /^resource "aws_lambda_function"/ {
            inblock=1
            depth=0
            print
            next
        }
        inblock {
            line=$0
            n_open=gsub(/\{/,"{",line)
            n_close=gsub(/\}/,"}",line)
            depth += n_open - n_close

            if (depth <= 0 && $0 ~ /^\}/) {
                print "  lifecycle {"
                print "    ignore_changes = [filename, source_code_hash]"
                print "  }"
                print
                inblock=0
                next
            }
            print
            next
        }
        { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"

    local count
    count=$(grep -c "ignore_changes = \[filename, source_code_hash\]" "$file")
    log_info "Lifecycle added to $count Lambda functions"
}

#!/usr/bin/env bash

terraform_split_generated_config() {
    local env_dir="${TF_ENV_DIR}"
    local config_file="${env_dir}/auto_generated.tf"
    local imports_file="${env_dir}/imports_generated.tf"

    if [[ ! -f "$config_file" || ! -f "$imports_file" ]]; then
        log_error "auto_generated.tf or imports_generated.tf not found in $env_dir; run 'build' first."
        return 1
    fi

    terraform_ensure_category_dirs

    for cat in "${CATEGORIES[@]}"; do
        > "${env_dir}/${cat}/main.tf"
        > "${env_dir}/${cat}/imports_generated.tf"
    done

    log_info "Distributing resource blocks while preserving the original file..."
    awk -v env_dir="$env_dir" '
        function category(rtype) {
            if (rtype ~ /^aws_(instance|security_group|vpc|subnet|ebs_volume|network_interface|nat_gateway|internet_gateway|route_table|eip|key_pair|network_acl|default_network_acl|vpc_dhcp_options|ec2_transit_gateway|vpn_gateway|customer_gateway|vpn_connection|vpc_endpoint|flow_log)/) return "network"
            if (rtype ~ /^aws_ecs_/) return "ecs"
            if (rtype ~ /^aws_ssm_/) return "ssm"
            if (rtype ~ /^aws_lambda_/) return "lambda"
            if (rtype ~ /^aws_cloudwatch_log_group/) return "logs"
            if (rtype ~ /^aws_(lb|elb)/) return "elb"
            if (rtype ~ /^aws_kms_/) return "kms"
            if (rtype ~ /^aws_secretsmanager_/) return "secretsmanager"
            if (rtype ~ /^aws_s3_/) return "s3"
            if (rtype ~ /^aws_cloudwatch_event_/) return "events"
            if (rtype ~ /^aws_cloudformation_/) return "cloudformation"
            if (rtype ~ /^aws_iam_/) return "iam"
            if (rtype ~ /^aws_sns_/) return "sns"
            if (rtype ~ /^aws_ecr_/) return "ecr"
            if (rtype ~ /^aws_backup_/) return "backup"
            if (rtype ~ /^aws_api_gateway_/) return "apigateway"
            return "outros"
        }
        BEGIN { depth=0; capturing=0; buffer=""; cat="" }
        /^resource "/ {
            capturing=1
            buffer=$0"\n"
            depth=1
            match($0, /^resource "([a-zA-Z0-9_]+)"/, arr)
            cat = category(arr[1])
            next
        }
        capturing {
            buffer = buffer $0 "\n"
            n_open=gsub(/\{/,"{")
            n_close=gsub(/\}/,"}")
            depth += n_open - n_close
            if (depth <= 0) {
                outfile = env_dir "/" cat "/main.tf"
                printf "%s\n", buffer >> outfile
                capturing=0
                buffer=""
                next
            }
            next
        }
    ' "$config_file"

    log_info "Distributing import blocks while preserving the original file..."
    awk -v env_dir="$env_dir" '
        function category(rtype) {
            if (rtype ~ /^aws_(instance|security_group|vpc|subnet|ebs_volume|network_interface|nat_gateway|internet_gateway|route_table|eip|key_pair|network_acl|default_network_acl|vpc_dhcp_options|ec2_transit_gateway|vpn_gateway|customer_gateway|vpn_connection|vpc_endpoint|flow_log)/) return "network"
            if (rtype ~ /^aws_ecs_/) return "ecs"
            if (rtype ~ /^aws_ssm_/) return "ssm"
            if (rtype ~ /^aws_lambda_/) return "lambda"
            if (rtype ~ /^aws_cloudwatch_log_group/) return "logs"
            if (rtype ~ /^aws_(lb|elb)/) return "elb"
            if (rtype ~ /^aws_kms_/) return "kms"
            if (rtype ~ /^aws_secretsmanager_/) return "secretsmanager"
            if (rtype ~ /^aws_s3_/) return "s3"
            if (rtype ~ /^aws_cloudwatch_event_/) return "events"
            if (rtype ~ /^aws_cloudformation_/) return "cloudformation"
            if (rtype ~ /^aws_iam_/) return "iam"
            if (rtype ~ /^aws_sns_/) return "sns"
            if (rtype ~ /^aws_ecr_/) return "ecr"
            if (rtype ~ /^aws_backup_/) return "backup"
            if (rtype ~ /^aws_api_gateway_/) return "apigateway"
            return "outros"
        }
        BEGIN { capturing=0; buffer=""; cat="" }
        /^import \{/ { capturing=1; buffer=$0"\n"; next }
        capturing {
            buffer = buffer $0 "\n"
            if ($0 ~ /^[ \t]*to[ \t]*=/) {
                line=$0
                sub(/^[ \t]*to[ \t]*=[ \t]*/, "", line)
                gsub(/[ \t]*$/, "", line)
                split(line, parts, ".")
                cat = category(parts[1])
            }
            if ($0 ~ /^\}/) {
                outfile = env_dir "/" cat "/imports_generated.tf"
                printf "\n%s", buffer >> outfile
                capturing=0
                buffer=""
                next
            }
            next
        }
    ' "$imports_file"

    log_info "Split completed. Original files preserved: ${config_file} and ${imports_file}"

    for cat in "${CATEGORIES[@]}"; do
        local count
        count=$(grep -c "^import {" "${env_dir}/${cat}/imports_generated.tf" 2>/dev/null) || true
        [[ "$count" -gt 0 ]] && log_info "  $cat: $count resources"
    done

    return 0
}

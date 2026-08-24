#!/usr/bin/env bash

_strip_block() {
    local file="$1"
    local attr="$2"
    awk -v attr="$attr" '
        BEGIN { depth=0; skipping=0 }
        {
            if (!skipping && $0 ~ "^[ \t]*" attr "[ \t]*\\{") {
                skipping=1
                depth=1
                next
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

_strip_name_prefix_conflict() {
    local file="$1"
    awk '
        BEGIN { depth=0; capturing=0; buffer=""; has_name=0; has_name_prefix=0 }
        /^resource "/ { capturing=1; buffer=$0"\n"; depth=1; has_name=0; has_name_prefix=0; next }
        capturing {
            buffer = buffer $0 "\n"
            if ($0 ~ /^[ \t]*name[ \t]*=[ \t]*"[^"]+"[ \t]*$/) has_name=1
            if ($0 ~ /^[ \t]*name_prefix[ \t]*=[ \t]*"[^"]+"[ \t]*$/) has_name_prefix=1
            n_open=gsub(/\{/,"{")
            n_close=gsub(/\}/,"}")
            depth += n_open - n_close
            if (depth <= 0) {
                if (has_name && has_name_prefix) {
                    gsub(/\n[ \t]*name_prefix[ \t]*=[ \t]*"[^"]*"[ \t]*\n/, "\n", buffer)
                }
                printf "%s", buffer
                capturing=0
                next
            }
            next
        }
        { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

_strip_invalid_listener_order() {
    local file="$1"
    awk '
        function brace_delta(line, opens, closes) {
            opens = gsub(/\{/, "{", line)
            closes = gsub(/\}/, "}", line)
            return opens - closes
        }
        BEGIN { in_listener=0; depth=0; default_depth=0 }
        !in_listener && $0 ~ /^resource "aws_lb_listener"/ {
            in_listener=1
            depth=brace_delta($0)
            default_depth=0
            print
            next
        }
        in_listener {
            if ($0 ~ /^[ \t]*default_action[ \t]*\{/) {
                default_depth=depth+1
            }
            if (default_depth > 0 && $0 ~ /^[ \t]*order[ \t]*=[ \t]*0[ \t]*$/) {
                depth += brace_delta($0)
                next
            }
            depth += brace_delta($0)
            if (default_depth > 0 && depth < default_depth) {
                default_depth=0
            }
            print
            if (depth <= 0) {
                in_listener=0
                default_depth=0
            }
            next
        }
        { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

_strip_invalid_secretsmanager_names() {
    local file="$1"
    awk '
        function brace_delta(line, opens, closes) {
            opens = gsub(/\{/, "{", line)
            closes = gsub(/\}/, "}", line)
            return opens - closes
        }
        BEGIN { in_secret=0; depth=0 }
        !in_secret && $0 ~ /^resource "aws_secretsmanager_secret"/ {
            in_secret=1
            depth=brace_delta($0)
            print
            next
        }
        in_secret {
            if ($0 ~ /^[ \t]*name[ \t]*=[ \t]*"/) {
                value=$0
                sub(/^[ \t]*name[ \t]*=[ \t]*"/, "", value)
                sub(/"[ \t]*$/, "", value)
                if (value !~ /^[[:alnum:]\/_+=.@-]+$/) {
                    depth += brace_delta($0)
                    next
                }
            }
            depth += brace_delta($0)
            print
            if (depth <= 0) {
                in_secret=0
            }
            next
        }
        { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

_strip_unsupported_network_interface_types() {
    local file="$1"
    awk '
        /^[ \t]*interface_type[ \t]*=/ &&
            $0 !~ /"(efa|efa-only|branch|trunk)"[ \t]*$/ { next }
        { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

_strip_instance_conflicts() {
    local file="$1"
    awk '
        function brace_delta(line, opens, closes) {
            opens = gsub(/\{/, "{", line)
            closes = gsub(/\}/, "}", line)
            return opens - closes
        }
        function flush_instance(    i, line, in_launch) {
            in_launch=0
            for (i=1; i<=line_count; i++) {
                line=lines[i]
                if (line ~ /^[ \t]*launch_template[ \t]*\{/) {
                    in_launch=1
                }
                if (has_primary && line ~ /^[ \t]*(associate_public_ip_address|private_ip|secondary_private_ips|security_groups|subnet_id|vpc_security_group_ids|source_dest_check)[ \t]*=/) {
                    continue
                }
                if (in_launch && has_launch_id && line ~ /^[ \t]*name[ \t]*=/) {
                    continue
                }
                print line
                if (in_launch && line ~ /^[ \t]*\}/) {
                    in_launch=0
                }
            }
            delete lines
            line_count=0
        }
        BEGIN { capturing=0; depth=0; line_count=0; has_primary=0; has_launch_id=0 }
        !capturing && $0 ~ /^resource "aws_instance"/ {
            capturing=1
            depth=brace_delta($0)
            line_count=1
            lines[line_count]=$0
            has_primary=0
            has_launch_id=0
            next
        }
        capturing {
            line_count++
            lines[line_count]=$0
            if ($0 ~ /^[ \t]*primary_network_interface[ \t]*\{/) has_primary=1
            if ($0 ~ /^[ \t]*launch_template[ \t]*\{/) in_launch=1
            if (in_launch && $0 ~ /^[ \t]*id[ \t]*=/) has_launch_id=1
            if (in_launch && $0 ~ /^[ \t]*\}/) in_launch=0
            depth += brace_delta($0)
            if (depth <= 0) {
                flush_instance()
                capturing=0
            }
            next
        }
        { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

_strip_disabled_block() {
    local file="$1"
    local attr="$2"
    awk -v attr="$attr" '
        BEGIN { depth=0; capturing=0; buffer=""; disabled=0; meaningful=0 }
        !capturing && $0 ~ "^[ \t]*" attr "[ \t]*\\{" {
            capturing=1
            buffer=$0"\n"
            disabled=0
            meaningful=0
            line=$0
            n_open=gsub(/\{/,"{",line)
            n_close=gsub(/\}/,"}",line)
            depth=n_open-n_close
            next
        }
        capturing {
            buffer=buffer $0"\n"
            if ($0 ~ /^[ \t]*enabled[ \t]*=[ \t]*false[ \t]*$/) disabled=1
            if ($0 ~ /^[ \t]*duration[ \t]*=/ && $0 !~ /^[ \t]*duration[ \t]*=[ \t]*0[ \t]*$/) meaningful=1
            line=$0
            n_open=gsub(/\{/,"{",line)
            n_close=gsub(/\}/,"}",line)
            depth += n_open-n_close
            if (depth <= 0) {
                if (!disabled || meaningful) printf "%s", buffer
                capturing=0
                buffer=""
            }
            next
        }
        { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

_strip_invalid_backup_advanced_setting() {
    local file="$1"
    awk '
        BEGIN { depth=0; capturing=0; buffer=""; invalid=0 }
        !capturing && $0 ~ /^[ \t]*advanced_backup_setting[ \t]*\{/ {
            capturing=1
            buffer=$0"\n"
            invalid=0
            line=$0
            n_open=gsub(/\{/, "{", line)
            n_close=gsub(/\}/, "}", line)
            depth=n_open-n_close
            next
        }
        capturing {
            buffer=buffer $0"\n"
            if ($0 ~ /^[ \t]*resource_type[ \t]*=[ \t]*"S3"[ \t]*$/) {
                invalid=1
            }
            line=$0
            n_open=gsub(/\{/, "{", line)
            n_close=gsub(/\}/, "}", line)
            depth += n_open-n_close
            if (depth <= 0) {
                if (!invalid) printf "%s", buffer
                capturing=0
                buffer=""
            }
            next
        }
        { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

_add_import_lifecycle() {
    local file="$1"
    local resource_type="$2"
    local condition="$3"
    local ignore_changes="$4"
    awk -v resource_type="$resource_type" -v condition="$condition" -v ignore_changes="$ignore_changes" '
        BEGIN { depth=0; capturing=0; matches=0; has_lifecycle=0 }
        $0 ~ "^resource \"" resource_type "\"" {
            capturing=1
            depth=1
            matches=(condition == "")
            has_lifecycle=0
            print
            next
        }
        capturing {
            if (condition != "" && $0 ~ condition) matches=1
            if (depth == 1 && $0 ~ /^[ \t]*lifecycle[ \t]*\{/) {
                has_lifecycle=1
            }
            line=$0
            n_open=gsub(/\{/,"{",line)
            n_close=gsub(/\}/,"}",line)
            depth += n_open-n_close
            if (depth <= 0 && $0 ~ /^\}/) {
                if (matches && !has_lifecycle) {
                    print "  lifecycle {"
                    print "    ignore_changes = [" ignore_changes "]"
                    print "  }"
                    print ""
                }
                print
                capturing=0
                next
            }
            print
            next
        }
        { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

_strip_disabled_mutual_authentication_settings() {
    local file="$1"

    awk '
        /^[ \t]*mutual_authentication[ \t]*\{/ {
            capturing=1
            depth=1
            count=1
            lines[count]=$0
            mode_off=0
            next
        }
        capturing {
            count++
            lines[count]=$0
            line=$0
            n_open=gsub(/\{/,"{",line)
            n_close=gsub(/\}/,"}",line)
            depth += n_open-n_close
            if ($0 ~ /^[ \t]*mode[ \t]*=[ \t]*"off"[ \t]*$/) {
                mode_off=1
            }
            if (depth <= 0) {
                for (i=1; i<=count; i++) {
                    if (mode_off &&
                        lines[i] ~ /^[ \t]*ignore_client_certificate_expiry[ \t]*=/) {
                        continue
                    }
                    print lines[i]
                }
                delete lines
                capturing=0
                count=0
            }
            next
        }
        { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

terraform_cleanup_generated_config() {
    local file="${TF_ENV_DIR}/auto_generated.tf"
    local backup="${file}.bak.$(date +%s)"

    cp "$file" "$backup"
    log_info "Backup saved to: $backup"

    sed -i -E '/^\s*rotation_period_in_days\s*=\s*0\s*$/d' "$file"
    sed -i -E '/^\s*signature_version\s*=\s*0\s*$/d' "$file"
    sed -i -E '/^\s*target_control_port\s*=\s*0\s*$/d' "$file"
    sed -i -E '/^\s*volume_initialization_rate\s*=\s*0\s*$/d' "$file"
    sed -i -E '/^\s*throughput\s*=\s*0\s*$/d' "$file"

    sed -i -E '/^\s*availability_zone_id\s*=/d' "$file"
    sed -i -E '/^\s*ipv4_prefix_count\s*=/d' "$file"
    sed -i -E '/^\s*ipv6_address_count\s*=/d' "$file"
    sed -i -E '/^\s*ipv6_prefix_count\s*=/d' "$file"
    sed -i -E '/^\s*private_ip_list\s*=/d' "$file"
    sed -i -E '/^\s*private_ips_count\s*=/d' "$file"

    sed -i -E '/^\s*customer_owned_ipv4_pool\s*=/d' "$file"
    sed -i -E '/^\s*map_customer_owned_ip_on_launch\s*=/d' "$file"
    sed -i -E '/^\s*outpost_arn\s*=/d' "$file"

    sed -i -E '/^\s*ipv6_ipam_pool_id\s*=/d' "$file"
    sed -i -E '/^\s*ipv6_netmask_length\s*=\s*0\s*$/d' "$file"

    sed -i -E '/^\s*enable_lni_at_device_index\s*=\s*0\s*$/d' "$file"

    sed -i -E '/^\s*private_dns_specified_domains\s*=\s*\[\]\s*$/d' "$file"
    sed -i -E '/^\s*gateway_load_balancer_arns\s*=\s*\[\]\s*$/d' "$file"
    sed -i -E '/^\s*vpc_endpoint_ids\s*=\s*\[\]\s*$/d' "$file"

    for f in carrier_gateway_id core_network_arn destination_prefix_list_id \
             egress_only_gateway_id ipv6_cidr_block local_gateway_id \
             nat_gateway_id network_interface_id odb_network_arn \
             vpc_endpoint_id vpc_peering_connection_id gateway_id transit_gateway_id; do
        sed -i -E "s/^(\s*${f}\s*=\s*)\"\"\s*\$/\1null/" "$file"
    done

    sed -i -E '/^\s*duration\s*=\s*0\s*$/d' "$file"
    sed -i -E '/^\s*force_overwrite_replica_secret\s*=\s*false\s*$/d' "$file"
    sed -i -E '/^\s*recovery_window_in_days\s*=\s*30\s*$/d' "$file"
    sed -i -E '/^\s*force_overwrite_replica_secret\s*=\s*null\s*$/d' "$file"
    sed -i -E '/^\s*recovery_window_in_days\s*=\s*null\s*$/d' "$file"
    sed -i -E '/^\s*deregistration_delay\s*=\s*null\s*$/d' "$file"
    sed -i -E '/^\s*lambda_multi_value_headers_enabled\s*=\s*false\s*$/d' "$file"
    sed -i -E '/^\s*lambda_multi_value_headers_enabled\s*=\s*null\s*$/d' "$file"
    sed -i -E '/^\s*proxy_protocol_v2\s*=\s*false\s*$/d' "$file"
    sed -i -E '/^\s*proxy_protocol_v2\s*=\s*null\s*$/d' "$file"
    sed -i -E '/^\s*slow_start\s*=\s*null\s*$/d' "$file"

    _strip_unsupported_network_interface_types "$file"
    _strip_instance_conflicts "$file"
    sed -i -E '/^\s*ipv6_address_list\s*=\s*\[\]\s*$/d' "$file"
    sed -i -E '/^\s*ipv6_addresses\s*=\s*\[\]\s*$/d' "$file"

    _strip_block "$file" "subnet_mapping"
    _strip_block "$file" "target_failover"
    _strip_block "$file" "target_health_state"
    _strip_invalid_backup_advanced_setting "$file"
    sed -i -E '/^\s*(target_failover|target_health_state)\s*\{\s*\}\s*$/d' "$file"
    _strip_disabled_block "$file" "stickiness"
    _strip_name_prefix_conflict "$file"
    _strip_invalid_listener_order "$file"
    _strip_disabled_mutual_authentication_settings "$file"
    _strip_invalid_secretsmanager_names "$file"
    _add_import_lifecycle "$file" "aws_secretsmanager_secret" "" \
        "force_overwrite_replica_secret, recovery_window_in_days"
    _add_import_lifecycle "$file" "aws_lb_target_group" \
        "^[ \t]*target_type[ \t]*=[ \t]*\"alb\"" \
        "deregistration_delay, lambda_multi_value_headers_enabled, proxy_protocol_v2, slow_start"
    # SSM documents return semantically equivalent content with provider
    # formatting/version metadata. Preserve the imported document without
    # turning that representation difference into an in-place change.
    _add_import_lifecycle "$file" "aws_ssm_document" "" "content"
    _add_import_lifecycle "$file" "aws_backup_plan" "" "advanced_backup_setting"
    _add_import_lifecycle "$file" "aws_cloudwatch_log_group" "" \
        "retention_in_days"

    log_info "Cleanup completed."
}

resource "aws_lb" "this" {
  client_keep_alive                                            = var.client_keep_alive
  desync_mitigation_mode                                       = var.desync_mitigation_mode
  dns_record_client_routing_policy                             = var.dns_record_client_routing_policy
  drop_invalid_header_fields                                   = var.drop_invalid_header_fields
  enable_cross_zone_load_balancing                             = var.enable_cross_zone_load_balancing
  enable_deletion_protection                                   = var.enable_deletion_protection
  enable_http2                                                 = var.enable_http2
  enable_prefix_for_ipv6_source_nat                            = var.enable_prefix_for_ipv6_source_nat
  enable_tls_version_and_cipher_suite_headers                  = var.enable_tls_version_and_cipher_suite_headers
  enable_waf_fail_open                                         = var.enable_waf_fail_open
  enable_xff_client_port                                       = var.enable_xff_client_port
  enable_zonal_shift                                           = var.enable_zonal_shift
  enforce_security_group_inbound_rules_on_private_link_traffic = var.enforce_private_link_security_group_rules
  idle_timeout                                                 = var.idle_timeout
  internal                                                     = var.internal
  ip_address_type                                              = var.ip_address_type
  load_balancer_type                                           = var.load_balancer_type
  name                                                         = var.name
  preserve_host_header                                         = var.preserve_host_header
  secondary_ips_auto_assigned_per_subnet                       = var.secondary_ips_auto_assigned_per_subnet
  security_groups                                              = var.security_groups
  subnets                                                      = var.subnets
  tags                                                         = var.tags
  xff_header_processing_mode                                   = var.xff_header_processing_mode

  access_logs {
    bucket  = var.access_logs_bucket
    enabled = var.access_logs_enabled
    prefix  = var.access_logs_prefix
  }

  dynamic "connection_logs" {
    for_each = var.connection_logs_enabled == null ? [] : [1]
    content {
      bucket  = var.connection_logs_bucket
      enabled = var.connection_logs_enabled
      prefix  = var.connection_logs_prefix
    }
  }

  dynamic "health_check_logs" {
    for_each = var.health_check_logs_enabled == null ? [] : [1]
    content {
      bucket  = var.health_check_logs_bucket
      enabled = var.health_check_logs_enabled
      prefix  = var.health_check_logs_prefix
    }
  }
}

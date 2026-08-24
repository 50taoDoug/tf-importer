variable "client_keep_alive" {
  type    = number
  default = null
}

variable "desync_mitigation_mode" {
  type    = string
  default = null
}

variable "dns_record_client_routing_policy" {
  type    = string
  default = null
}

variable "drop_invalid_header_fields" {
  type    = bool
  default = null
}

variable "enable_cross_zone_load_balancing" {
  type = bool
}

variable "enable_deletion_protection" {
  type = bool
}

variable "enable_http2" {
  type    = bool
  default = null
}

variable "enable_prefix_for_ipv6_source_nat" {
  type = string
}

variable "enable_tls_version_and_cipher_suite_headers" {
  type    = bool
  default = null
}

variable "enable_waf_fail_open" {
  type    = bool
  default = null
}

variable "enable_xff_client_port" {
  type    = bool
  default = null
}

variable "enable_zonal_shift" {
  type = bool
}

variable "enforce_private_link_security_group_rules" {
  type    = string
  default = null
}

variable "idle_timeout" {
  type    = number
  default = null
}

variable "internal" {
  type = bool
}

variable "ip_address_type" {
  type = string
}

variable "load_balancer_type" {
  type = string
}

variable "name" {
  type = string
}

variable "preserve_host_header" {
  type    = bool
  default = null
}

variable "secondary_ips_auto_assigned_per_subnet" {
  type    = number
  default = null
}

variable "security_groups" {
  type = list(string)
}

variable "subnets" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}

variable "xff_header_processing_mode" {
  type    = string
  default = null
}

variable "access_logs_bucket" {
  type = string
}

variable "access_logs_enabled" {
  type = bool
}

variable "access_logs_prefix" {
  type    = string
  default = null
}

variable "connection_logs_bucket" {
  type    = string
  default = null
}

variable "connection_logs_enabled" {
  type    = bool
  default = null
}

variable "connection_logs_prefix" {
  type    = string
  default = null
}

variable "health_check_logs_bucket" {
  type    = string
  default = null
}

variable "health_check_logs_enabled" {
  type    = bool
  default = null
}

variable "health_check_logs_prefix" {
  type    = string
  default = null
}

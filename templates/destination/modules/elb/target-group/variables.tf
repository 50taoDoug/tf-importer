variable "connection_termination" {
  type    = bool
  default = null
}

variable "deregistration_delay" {
  type    = number
  default = null
}

variable "ip_address_type" {
  type = string
}

variable "load_balancing_algorithm_type" {
  type    = string
  default = null
}

variable "load_balancing_anomaly_mitigation" {
  type    = string
  default = null
}

variable "load_balancing_cross_zone_enabled" {
  type    = string
  default = null
}

variable "name" {
  type = string
}

variable "port" {
  type = number
}

variable "preserve_client_ip" {
  type    = string
  default = null
}

variable "protocol" {
  type = string
}

variable "protocol_version" {
  type    = string
  default = null
}

variable "slow_start" {
  type    = number
  default = null
}

variable "tags" {
  type = map(string)
}

variable "target_type" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "health_check_enabled" {
  type = bool
}

variable "health_check_healthy_threshold" {
  type = number
}

variable "health_check_interval" {
  type = number
}

variable "health_check_matcher" {
  type    = string
  default = null
}

variable "health_check_path" {
  type    = string
  default = null
}

variable "health_check_port" {
  type = string
}

variable "health_check_protocol" {
  type = string
}

variable "health_check_timeout" {
  type = number
}

variable "health_check_unhealthy_threshold" {
  type = number
}

variable "dns_failover_minimum_count" {
  type = string
}

variable "dns_failover_minimum_percentage" {
  type = string
}

variable "unhealthy_routing_minimum_count" {
  type = string
}

variable "unhealthy_routing_minimum_percentage" {
  type = string
}

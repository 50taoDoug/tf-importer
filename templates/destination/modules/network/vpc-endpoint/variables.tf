variable "ip_address_type" {
  type = string
}

variable "policy" {
  type = string
}

variable "private_dns_enabled" {
  type = bool
}

variable "region" {
  type = string
}

variable "route_table_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "service_name" {
  type = string
}

variable "service_region" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}

variable "vpc_endpoint_type" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "dns_record_ip_type" {
  type = string
}

variable "private_dns_only_for_inbound_resolver_endpoint" {
  type = bool
}

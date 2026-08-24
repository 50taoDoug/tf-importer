variable "cidr_block" {
  type = string
}

variable "instance_tenancy" {
  type = string
}

variable "assign_generated_ipv6_cidr_block" {
  type = bool
}

variable "enable_dns_support" {
  type = bool
}

variable "enable_dns_hostnames" {
  type = bool
}

variable "enable_network_address_usage_metrics" {
  type = bool
}

variable "tags" {
  type = map(string)
}

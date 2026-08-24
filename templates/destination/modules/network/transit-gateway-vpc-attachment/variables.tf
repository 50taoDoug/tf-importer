variable "appliance_mode_support" {
  type = string
}

variable "dns_support" {
  type = string
}

variable "ipv6_support" {
  type = string
}

variable "region" {
  type = string
}

variable "security_group_referencing_support" {
  type = string
}

variable "subnet_ids" {
  type = set(string)
}

variable "tags" {
  type = map(string)
}

variable "default_route_table_association" {
  type = bool
}

variable "default_route_table_propagation" {
  type = bool
}

variable "transit_gateway_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

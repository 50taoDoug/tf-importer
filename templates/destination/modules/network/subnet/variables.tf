variable "vpc_id" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "availability_zone" {
  type = string
}

variable "map_public_ip_on_launch" {
  type = bool
}

variable "assign_ipv6_address_on_creation" {
  type = bool
}

variable "enable_dns64" {
  type = bool
}

variable "private_dns_hostname_type_on_launch" {
  type = string
}

variable "enable_resource_name_dns_a_record_on_launch" {
  type = bool
}

variable "enable_resource_name_dns_aaaa_record_on_launch" {
  type = bool
}

variable "ipv6_native" {
  type = bool
}

variable "tags" {
  type = map(string)
}

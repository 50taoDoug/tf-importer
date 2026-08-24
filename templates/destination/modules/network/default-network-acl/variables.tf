variable "default_network_acl_id" { type = string }
variable "region" { type = string }
variable "subnet_ids" { type = list(string) }
variable "tags" { type = map(string) }
variable "egress_action" { type = string }
variable "egress_cidr_block" { type = string }
variable "egress_from_port" { type = number }
variable "egress_icmp_code" { type = number }
variable "egress_icmp_type" { type = number }
variable "egress_ipv6_cidr_block" {
  type    = string
  default = null
}
variable "egress_protocol" { type = string }
variable "egress_rule_no" { type = number }
variable "egress_to_port" { type = number }
variable "ingress_action" { type = string }
variable "ingress_cidr_block" { type = string }
variable "ingress_from_port" { type = number }
variable "ingress_icmp_code" { type = number }
variable "ingress_icmp_type" { type = number }
variable "ingress_ipv6_cidr_block" {
  type    = string
  default = null
}
variable "ingress_protocol" { type = string }
variable "ingress_rule_no" { type = number }
variable "ingress_to_port" { type = number }

resource "aws_default_network_acl" "this" {
  default_network_acl_id = var.default_network_acl_id
  region                 = var.region
  subnet_ids             = var.subnet_ids
  tags                   = var.tags

  egress {
    action          = var.egress_action
    cidr_block      = var.egress_cidr_block
    from_port       = var.egress_from_port
    icmp_code       = var.egress_icmp_code
    icmp_type       = var.egress_icmp_type
    ipv6_cidr_block = var.egress_ipv6_cidr_block
    protocol        = var.egress_protocol
    rule_no         = var.egress_rule_no
    to_port         = var.egress_to_port
  }

  ingress {
    action          = var.ingress_action
    cidr_block      = var.ingress_cidr_block
    from_port       = var.ingress_from_port
    icmp_code       = var.ingress_icmp_code
    icmp_type       = var.ingress_icmp_type
    ipv6_cidr_block = var.ingress_ipv6_cidr_block
    protocol        = var.ingress_protocol
    rule_no         = var.ingress_rule_no
    to_port         = var.ingress_to_port
  }
}

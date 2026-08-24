resource "aws_security_group" "this" {
  description            = var.description
  egress                 = var.egress
  ingress                = var.ingress
  name                   = var.name
  region                 = var.region
  revoke_rules_on_delete = var.revoke_rules_on_delete
  tags                   = var.tags
  vpc_id                 = var.vpc_id
}

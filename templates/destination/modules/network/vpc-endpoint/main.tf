resource "aws_vpc_endpoint" "this" {
  ip_address_type     = var.ip_address_type
  policy              = var.policy
  private_dns_enabled = var.private_dns_enabled
  region              = var.region
  route_table_ids     = var.route_table_ids
  security_group_ids  = var.security_group_ids
  service_name        = var.service_name
  service_region      = var.service_region
  subnet_ids          = var.subnet_ids
  tags                = var.tags
  vpc_endpoint_type   = var.vpc_endpoint_type
  vpc_id              = var.vpc_id

  dns_options {
    dns_record_ip_type                             = var.dns_record_ip_type
    private_dns_only_for_inbound_resolver_endpoint = var.private_dns_only_for_inbound_resolver_endpoint
  }
}

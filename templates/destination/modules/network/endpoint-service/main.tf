resource "aws_vpc_endpoint_service" "this" {
  acceptance_required        = var.acceptance_required
  allowed_principals         = var.allowed_principals
  network_load_balancer_arns = var.network_load_balancer_arns
  region                     = var.region
  supported_ip_address_types = var.supported_ip_address_types
  supported_regions          = var.supported_regions
  tags                       = var.tags
}

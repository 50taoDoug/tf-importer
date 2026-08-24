resource "aws_eip" "this" {
  domain               = var.domain
  network_border_group = var.network_border_group
  public_ipv4_pool     = var.public_ipv4_pool
  region               = var.region
  tags                 = var.tags
}

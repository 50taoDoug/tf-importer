resource "aws_route_table" "this" {
  propagating_vgws = var.propagating_vgws
  region           = var.region
  route            = var.routes
  tags             = var.tags
  vpc_id           = var.vpc_id
}

resource "aws_ssm_parameter" "this" {
  name            = var.name
  description     = var.description
  type            = var.type
  value           = var.value
  tier            = var.tier
  data_type       = var.data_type
  allowed_pattern = var.allowed_pattern
  overwrite       = var.overwrite
  tags            = var.tags
}

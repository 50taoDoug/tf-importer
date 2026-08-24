resource "aws_cloudformation_stack" "this" {
  capabilities       = var.capabilities
  disable_rollback   = var.disable_rollback
  name               = var.name
  parameters         = var.parameters
  region             = var.region
  tags               = var.tags
  template_body      = var.template_body
  timeout_in_minutes = var.timeout_in_minutes
}

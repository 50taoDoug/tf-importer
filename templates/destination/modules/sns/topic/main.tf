resource "aws_sns_topic" "this" {
  name              = var.name
  display_name      = var.display_name
  kms_master_key_id = var.kms_master_key_id
  policy            = var.policy_json
  tracing_config    = var.tracing_config
  tags              = var.tags
}

resource "aws_kms_key" "this" {
  description                        = var.description
  customer_master_key_spec           = "SYMMETRIC_DEFAULT"
  key_usage                          = "ENCRYPT_DECRYPT"
  is_enabled                         = true
  multi_region                       = false
  enable_key_rotation                = var.enable_key_rotation
  rotation_period_in_days            = var.enable_key_rotation ? 365 : null
  bypass_policy_lockout_safety_check = var.bypass_policy_lockout_safety_check
  policy                             = var.policy_json
  tags                               = var.tags
}

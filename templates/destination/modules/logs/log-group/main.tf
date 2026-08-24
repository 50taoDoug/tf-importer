resource "aws_cloudwatch_log_group" "this" {
  name                        = var.name
  retention_in_days           = var.retention_in_days
  kms_key_id                  = var.kms_key_id
  log_group_class             = var.log_group_class
  deletion_protection_enabled = var.deletion_protection_enabled
  skip_destroy                = var.skip_destroy
  tags                        = var.tags

  # Imported log groups can report provider-specific retention sentinels
  # (for example 3653 for an effectively indefinite value). Preserve the
  # remote retention during the import-only baseline.
  lifecycle {
    ignore_changes = [retention_in_days]
  }
}

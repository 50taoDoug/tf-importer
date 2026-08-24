resource "aws_secretsmanager_secret" "this" {
  name        = var.name
  description = var.description
  kms_key_id  = var.kms_key_id
  tags        = var.tags

  lifecycle {
    ignore_changes = [
      force_overwrite_replica_secret,
      recovery_window_in_days,
    ]
  }
}

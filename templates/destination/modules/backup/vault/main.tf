resource "aws_backup_vault" "this" {
  kms_key_arn = var.kms_key_arn
  name        = var.name
  region      = var.region
  tags        = var.tags
}

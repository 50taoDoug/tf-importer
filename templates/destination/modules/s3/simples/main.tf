resource "aws_s3_bucket" "this" {
  bucket              = var.bucket_name
  bucket_namespace    = "global"
  force_destroy       = false
  object_lock_enabled = false
  tags                = var.tags
}

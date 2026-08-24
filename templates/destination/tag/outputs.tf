output "tags" {
  value = merge(local.base_tags, var.extra_tags)
}

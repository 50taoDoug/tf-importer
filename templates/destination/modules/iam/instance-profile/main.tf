resource "aws_iam_instance_profile" "this" {
  name = var.name
  path = "/"
  role = var.role
  tags = var.tags
}

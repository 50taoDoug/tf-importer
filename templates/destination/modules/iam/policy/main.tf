resource "aws_iam_policy" "this" {
  name        = var.name
  description = var.description
  path        = var.path
  policy      = var.policy_json
  tags        = var.tags
}

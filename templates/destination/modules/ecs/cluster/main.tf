resource "aws_ecs_cluster" "this" {
  name = var.name
  tags = var.tags

  setting {
    name  = var.container_insights_name
    value = var.container_insights_value
  }
}

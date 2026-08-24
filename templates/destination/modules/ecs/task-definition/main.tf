resource "aws_ecs_task_definition" "this" {
  container_definitions    = var.container_definitions
  cpu                      = var.cpu
  enable_fault_injection   = var.enable_fault_injection
  execution_role_arn       = var.execution_role_arn
  family                   = var.family
  memory                   = var.memory
  network_mode             = var.network_mode
  region                   = var.region
  requires_compatibilities = var.requires_compatibilities
  tags                     = var.tags
  track_latest             = var.track_latest
}

resource "aws_ecs_service" "this" {
  availability_zone_rebalancing      = var.availability_zone_rebalancing
  cluster                            = var.cluster
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  desired_count                      = var.desired_count
  enable_ecs_managed_tags            = var.enable_ecs_managed_tags
  enable_execute_command             = var.enable_execute_command
  force_delete                       = var.force_delete
  force_new_deployment               = var.force_new_deployment
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  iam_role                           = var.iam_role
  launch_type                        = var.launch_type
  name                               = var.name
  platform_version                   = var.platform_version
  propagate_tags                     = var.propagate_tags
  scheduling_strategy                = var.scheduling_strategy
  sigint_rollback                    = var.sigint_rollback
  tags                               = var.tags
  task_definition                    = var.task_definition
  triggers                           = var.triggers
  wait_for_steady_state              = var.wait_for_steady_state

  deployment_circuit_breaker {
    enable   = var.deployment_circuit_breaker_enable
    rollback = var.deployment_circuit_breaker_rollback
  }

  deployment_configuration {
    bake_time_in_minutes = var.deployment_bake_time_in_minutes
    strategy             = var.deployment_strategy
  }

  deployment_controller {
    type = var.deployment_controller_type
  }

  load_balancer {
    container_name   = var.load_balancer_container_name
    container_port   = var.load_balancer_container_port
    elb_name         = var.load_balancer_elb_name
    target_group_arn = var.load_balancer_target_group_arn
  }

  network_configuration {
    assign_public_ip = var.assign_public_ip
    security_groups  = var.security_groups
    subnets          = var.subnets
  }
}

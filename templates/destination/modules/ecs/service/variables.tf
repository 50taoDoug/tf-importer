variable "availability_zone_rebalancing" {
  type = string
}

variable "cluster" {
  type = string
}

variable "deployment_maximum_percent" {
  type = number
}

variable "deployment_minimum_healthy_percent" {
  type = number
}

variable "desired_count" {
  type = number
}

variable "enable_ecs_managed_tags" {
  type = bool
}

variable "enable_execute_command" {
  type = bool
}

variable "force_delete" {
  type    = bool
  default = null
}

variable "force_new_deployment" {
  type    = bool
  default = null
}

variable "health_check_grace_period_seconds" {
  type = number
}

variable "iam_role" {
  type = string
}

variable "launch_type" {
  type = string
}

variable "name" {
  type = string
}

variable "platform_version" {
  type = string
}

variable "propagate_tags" {
  type = string
}

variable "scheduling_strategy" {
  type = string
}

variable "sigint_rollback" {
  type    = bool
  default = null
}

variable "tags" {
  type = map(string)
}

variable "task_definition" {
  type = string
}

variable "triggers" {
  type = map(string)
}

variable "wait_for_steady_state" {
  type    = bool
  default = null
}

variable "deployment_circuit_breaker_enable" {
  type = bool
}

variable "deployment_circuit_breaker_rollback" {
  type = bool
}

variable "deployment_bake_time_in_minutes" {
  type = number
}

variable "deployment_strategy" {
  type = string
}

variable "deployment_controller_type" {
  type = string
}

variable "load_balancer_container_name" {
  type = string
}

variable "load_balancer_container_port" {
  type = number
}

variable "load_balancer_elb_name" {
  type    = string
  default = null
}

variable "load_balancer_target_group_arn" {
  type = string
}

variable "assign_public_ip" {
  type = bool
}

variable "security_groups" {
  type = list(string)
}

variable "subnets" {
  type = list(string)
}

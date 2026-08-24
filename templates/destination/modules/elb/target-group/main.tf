resource "aws_lb_target_group" "this" {
  connection_termination            = var.connection_termination
  deregistration_delay              = var.deregistration_delay
  ip_address_type                   = var.ip_address_type
  load_balancing_algorithm_type     = var.load_balancing_algorithm_type
  load_balancing_anomaly_mitigation = var.load_balancing_anomaly_mitigation
  load_balancing_cross_zone_enabled = var.load_balancing_cross_zone_enabled
  name                              = var.name
  port                              = var.port
  preserve_client_ip                = var.preserve_client_ip
  protocol                          = var.protocol
  protocol_version                  = var.protocol_version
  slow_start                        = var.slow_start
  tags                              = var.tags
  target_type                       = var.target_type
  vpc_id                            = var.vpc_id

  health_check {
    enabled             = var.health_check_enabled
    healthy_threshold   = var.health_check_healthy_threshold
    interval            = var.health_check_interval
    matcher             = var.health_check_matcher
    path                = var.health_check_path
    port                = var.health_check_port
    protocol            = var.health_check_protocol
    timeout             = var.health_check_timeout
    unhealthy_threshold = var.health_check_unhealthy_threshold
  }

  target_group_health {
    dns_failover {
      minimum_healthy_targets_count      = var.dns_failover_minimum_count
      minimum_healthy_targets_percentage = var.dns_failover_minimum_percentage
    }

    unhealthy_state_routing {
      minimum_healthy_targets_count      = var.unhealthy_routing_minimum_count
      minimum_healthy_targets_percentage = var.unhealthy_routing_minimum_percentage
    }
  }

  lifecycle {
    ignore_changes = [
      deregistration_delay,
      lambda_multi_value_headers_enabled,
      proxy_protocol_v2,
      slow_start,
    ]
  }
}

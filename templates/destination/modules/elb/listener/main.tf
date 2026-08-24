resource "aws_lb_listener" "this" {
  alpn_policy                          = var.alpn_policy
  certificate_arn                      = var.certificate_arn
  load_balancer_arn                    = var.load_balancer_arn
  port                                 = var.port
  protocol                             = var.protocol
  routing_http_response_server_enabled = var.routing_http_response_server_enabled
  tags                                 = var.tags
  tcp_idle_timeout_seconds             = var.tcp_idle_timeout_seconds

  default_action {
    order            = var.default_action_order
    target_group_arn = var.default_action_target_group_arn
    type             = var.default_action_type

    dynamic "forward" {
      for_each = var.forward_target_group_arn == null ? [] : [1]
      content {
        dynamic "stickiness" {
          for_each = var.forward_stickiness_duration == null ? [] : [1]
          content {
            duration = var.forward_stickiness_duration
            enabled  = var.forward_stickiness_enabled
          }
        }

        target_group {
          arn    = var.forward_target_group_arn
          weight = var.forward_target_group_weight
        }
      }
    }

    dynamic "fixed_response" {
      for_each = var.fixed_response_status_code == null ? [] : [1]
      content {
        content_type = var.fixed_response_content_type
        message_body = var.fixed_response_message_body
        status_code  = var.fixed_response_status_code
      }
    }
  }
}

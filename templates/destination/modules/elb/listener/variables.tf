variable "alpn_policy" {
  type    = string
  default = null
}

variable "certificate_arn" {
  type    = string
  default = null
}

variable "load_balancer_arn" {
  type = string
}

variable "port" {
  type = number
}

variable "protocol" {
  type = string
}

variable "routing_http_response_server_enabled" {
  type    = bool
  default = null
}

variable "tags" {
  type = map(string)
}

variable "tcp_idle_timeout_seconds" {
  type    = number
  default = null
}

variable "default_action_order" {
  type = number
}

variable "default_action_target_group_arn" {
  type = string
}

variable "default_action_type" {
  type = string
}

variable "forward_target_group_arn" {
  type    = string
  default = null
}

variable "forward_stickiness_duration" {
  type    = number
  default = null
}

variable "forward_stickiness_enabled" {
  type    = bool
  default = null
}

variable "forward_target_group_weight" {
  type    = number
  default = null
}

variable "fixed_response_content_type" {
  type    = string
  default = null
}

variable "fixed_response_message_body" {
  type    = string
  default = null
}

variable "fixed_response_status_code" {
  type    = string
  default = null
}

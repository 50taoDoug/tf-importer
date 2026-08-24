variable "name" {
  type = string
}

variable "description" {
  type    = string
  default = null
}

variable "event_bus_name" {
  type = string
}

variable "event_pattern" {
  type    = string
  default = null
}

variable "force_destroy" {
  type = bool
}

variable "role_arn" {
  type    = string
  default = null
}

variable "schedule_expression" {
  type    = string
  default = null
}

variable "state" {
  type = string
}

variable "tags" {
  type = map(string)
}

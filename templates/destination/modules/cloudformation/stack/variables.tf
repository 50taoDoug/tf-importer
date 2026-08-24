variable "capabilities" {
  type = set(string)
}

variable "disable_rollback" {
  type = bool
}

variable "name" {
  type = string
}

variable "parameters" {
  type = map(string)
}

variable "region" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "template_body" {
  type = string
}

variable "timeout_in_minutes" {
  type = number
}

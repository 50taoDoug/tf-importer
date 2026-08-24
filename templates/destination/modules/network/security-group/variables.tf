variable "description" {
  type = string
}

variable "egress" {
  type = any
}

variable "ingress" {
  type = any
}

variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "revoke_rules_on_delete" {
  type    = bool
  default = null
}

variable "tags" {
  type = map(string)
}

variable "vpc_id" {
  type = string
}

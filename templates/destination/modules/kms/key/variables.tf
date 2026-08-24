variable "description" {
  type = string
}

variable "policy_json" {
  type = string
}

variable "enable_key_rotation" {
  type    = bool
  default = true
}

variable "bypass_policy_lockout_safety_check" {
  type    = bool
  default = null
}

variable "tags" {
  type = map(string)
}

variable "name" {
  type = string
}

variable "display_name" {
  type    = string
  default = null
}

variable "kms_master_key_id" {
  type    = string
  default = null
}

variable "policy_json" {
  type    = string
  default = null
}

variable "tracing_config" {
  type    = string
  default = null
}

variable "tags" {
  type = map(string)
}

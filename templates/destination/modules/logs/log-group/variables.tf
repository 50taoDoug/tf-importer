variable "name" {
  type = string
}

variable "retention_in_days" {
  type = number
}

variable "kms_key_id" {
  type    = string
  default = null
}

variable "log_group_class" {
  type = string
}

variable "deletion_protection_enabled" {
  type = bool
}

variable "skip_destroy" {
  type = bool
}

variable "tags" {
  type = map(string)
}

variable "architectures" {
  type = list(string)
}

variable "code_sha256" {
  type = string
}

variable "description" {
  type    = string
  default = null
}

variable "filename" {
  type = string
}

variable "function_name" {
  type = string
}

variable "handler" {
  type = string
}

variable "kms_key_arn" {
  type    = string
  default = null
}

variable "layers" {
  type = list(string)
}

variable "memory_size" {
  type = number
}

variable "package_type" {
  type = string
}

variable "region" {
  type = string
}

variable "reserved_concurrent_executions" {
  type = number
}

variable "role" {
  type = string
}

variable "runtime" {
  type = string
}

variable "skip_destroy" {
  type = bool
}

variable "tags" {
  type = map(string)
}

variable "timeout" {
  type = number
}

variable "environment_variables" {
  type = map(string)
}

variable "ephemeral_storage_size" {
  type = number
}

variable "application_log_level" {
  type    = string
  default = null
}

variable "log_format" {
  type = string
}

variable "log_group" {
  type = string
}

variable "system_log_level" {
  type    = string
  default = null
}

variable "tracing_mode" {
  type = string
}

variable "name" {
  type = string
}

variable "description" {
  type    = string
  default = null
}

variable "type" {
  type = string
}

variable "value" {
  type      = string
  sensitive = true
}

variable "tier" {
  type = string
}

variable "data_type" {
  type = string
}

variable "allowed_pattern" {
  type    = string
  default = null
}

variable "overwrite" {
  type    = bool
  default = null
}

variable "tags" {
  type = map(string)
}

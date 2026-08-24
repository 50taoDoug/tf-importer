variable "name" {
  type = string
}

variable "description" {
  type    = string
  default = null
}

variable "kms_key_id" {
  type    = string
  default = null
}

variable "tags" {
  type = map(string)
}

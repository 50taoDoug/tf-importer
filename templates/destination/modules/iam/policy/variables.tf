variable "name" {
  type = string
}

variable "description" {
  type    = string
  default = null
}

variable "path" {
  type    = string
  default = "/"
}

variable "policy_json" {
  type = string
}

variable "tags" {
  type = map(string)
}

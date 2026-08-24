variable "propagating_vgws" {
  type = list(string)
}

variable "region" {
  type = string
}

variable "routes" {
  type = any
}

variable "tags" {
  type = map(string)
}

variable "vpc_id" {
  type = string
}

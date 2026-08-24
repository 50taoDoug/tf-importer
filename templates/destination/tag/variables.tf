variable "environment" {
  type = string
}

variable "project" {
  type = string
}

variable "cost_center" {
  type = string
}

variable "owner" {
  type    = string
  default = "N/A"
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}

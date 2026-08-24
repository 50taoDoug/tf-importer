variable "acceptance_required" {
  type = bool
}

variable "allowed_principals" {
  type = set(string)
}

variable "network_load_balancer_arns" {
  type = set(string)
}

variable "region" {
  type = string
}

variable "supported_ip_address_types" {
  type = set(string)
}

variable "supported_regions" {
  type = set(string)
}

variable "tags" {
  type = map(string)
}

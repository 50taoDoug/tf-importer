variable "domain_name" {
  type = string
}

variable "domain_name_servers" {
  type = list(string)
}

variable "netbios_name_servers" {
  type = list(string)
}

variable "ntp_servers" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}

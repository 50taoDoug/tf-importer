variable "iam_role_arn" {
  type    = string
  default = null
}

variable "log_destination" {
  type = string
}

variable "log_destination_type" {
  type = string
}

variable "log_format" {
  type = string
}

variable "max_aggregation_interval" {
  type = number
}

variable "region" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "traffic_type" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "destination_file_format" {
  type    = string
  default = null
}

variable "hive_compatible_partitions" {
  type    = bool
  default = null
}

variable "per_hour_partition" {
  type    = bool
  default = null
}

resource "aws_flow_log" "this" {
  iam_role_arn             = var.iam_role_arn
  log_destination          = var.log_destination
  log_destination_type     = var.log_destination_type
  log_format               = var.log_format
  max_aggregation_interval = var.max_aggregation_interval
  region                   = var.region
  tags                     = var.tags
  traffic_type             = var.traffic_type
  vpc_id                   = var.vpc_id

  dynamic "destination_options" {
    for_each = var.destination_file_format == null ? [] : [1]
    content {
      file_format                = var.destination_file_format
      hive_compatible_partitions = var.hive_compatible_partitions
      per_hour_partition         = var.per_hour_partition
    }
  }
}

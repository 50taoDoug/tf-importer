resource "aws_lambda_function" "this" {
  architectures                  = var.architectures
  code_sha256                    = var.code_sha256
  description                    = var.description
  filename                       = var.filename
  function_name                  = var.function_name
  handler                        = var.handler
  kms_key_arn                    = var.kms_key_arn
  layers                         = var.layers
  memory_size                    = var.memory_size
  package_type                   = var.package_type
  region                         = var.region
  reserved_concurrent_executions = var.reserved_concurrent_executions
  role                           = var.role
  runtime                        = var.runtime
  skip_destroy                   = var.skip_destroy
  tags                           = var.tags
  timeout                        = var.timeout

  environment {
    variables = var.environment_variables
  }

  ephemeral_storage {
    size = var.ephemeral_storage_size
  }

  logging_config {
    application_log_level = var.application_log_level
    log_format            = var.log_format
    log_group             = var.log_group
    system_log_level      = var.system_log_level
  }

  tracing_config {
    mode = var.tracing_mode
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
      publish,
      vpc_config,
      dead_letter_config,
    ]
  }
}

locals {
  base_tags = {
    CostCenter  = var.cost_center
    Environment = var.environment
    Owner       = var.owner
    Project     = var.project
  }
}

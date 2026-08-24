# `kms/key` Module

Standard symmetric KMS key. Fields such as `customer_master_key_spec`,
`key_usage`, and `multi_region` are fixed because all ten keys identified in
the `prd` environment use these values.

`enable_key_rotation` also controls `rotation_period_in_days` automatically:
365 days when enabled and `null` when disabled.

## Usage

```hcl
module "my_key" {
  source              = "../../../modules/kms/key"
  description         = "Key description"
  enable_key_rotation = true
  tags                = module.tags.tags
  policy_json = jsonencode({
    Statement = [...]
    Version   = "2012-10-17"
  })
}
```

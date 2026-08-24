# `iam/policy` Module

Generic IAM policy module. The policy document is passed as JSON through
`policy_json`. Each policy has unique content, so the module standardizes the
resource structure without abstracting the policy itself.

## Usage

```hcl
module "my_policy" {
  source      = "../../../modules/iam/policy"
  name        = "MyPolicy"
  description = "Policy description"
  policy_json = jsonencode({
    Statement = [...]
    Version   = "2012-10-17"
  })
  tags = module.tags.tags
}
```

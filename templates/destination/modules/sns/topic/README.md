# `sns/topic` Module

SNS topic module. Feedback fields (`*_feedback_role_arn` and
`*_feedback_sample_rate`) are omitted because all three topics identified in
`prd` use the provider defaults.

## Usage

```hcl
module "my_topic" {
  source = "../../../modules/sns/topic"
  name   = "my-topic"
  tags   = module.tags.tags
}
```

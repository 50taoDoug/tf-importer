# `tag` Module

Generates the project's standard resource tags and merges resource-specific
tags through `extra_tags`.

## Usage

```hcl
module "tags" {
  source      = "../../../tag"
  environment = "PRD"
  cost_center = "PROJECT-COST-CENTER"
}

# In another module:
tags = merge(module.tags.tags, { Accelerator = "AWSAccelerator" })
```

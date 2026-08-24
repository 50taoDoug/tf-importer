# `secretsmanager/secret` Module

Manages Secrets Manager metadata only: name, description, and tags. The secret
value is never managed by this module and must not be stored in versioned code.
Set it manually or through a secure external pipeline after an intentional
manual apply.

## Usage

```hcl
module "my_secret" {
  source = "../../../modules/secretsmanager/secret"
  name   = "my.secret"
  tags   = module.tags.tags
}
```

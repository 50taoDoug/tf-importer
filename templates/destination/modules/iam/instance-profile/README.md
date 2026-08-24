# Módulo `iam/instance-profile`

IAM Instance Profile básico, associando um nome a uma role.

## Uso

```hcl
module "meu_profile" {
  source = "../../../modules/iam/instance-profile"
  name   = "meu-profile"
  role   = "minha-role"
  tags   = module.tags.tags
}
```

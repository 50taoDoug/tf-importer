# Módulo `ecr/repository`

Repositório ECR. `encryption_type = "AES256"` é fixo — os 2 repositórios
identificados usam esse padrão. `image_tag_mutability` e `scan_on_push`
variam por repositório.

## Uso

```hcl
module "meu_repo" {
  source                = "../../../modules/ecr/repository"
  name                  = "meu-repo"
  image_tag_mutability  = "IMMUTABLE"
  scan_on_push          = false
  tags                  = module.tags.tags
}
```

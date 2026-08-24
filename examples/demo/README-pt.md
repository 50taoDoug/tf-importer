# Demo AWS sanitizado

[English](README.md)

Este demo cria um pequeno laboratório AWS privado por padrão, fora do
Terraform, e depois usa o `tf-importer` para adotá-lo em uma baseline Terraform
somente de importação.

Use uma conta pessoal de testes ou uma conta não produtiva dedicada. Podem
existir cobranças da AWS. Revise a arquitetura, as permissões, os preços e o
script de limpeza antes de criar qualquer recurso.

## Regras de segurança

- Use credenciais temporárias protegidas por MFA; nunca use root ou access keys
  de longa duração.
- Selecione uma única `AWS_REGION` explícita e confirme a conta ativa.
- Revise `delete-demo-resources.sh` antes de `create-demo-resources.sh`.
- Mantenha o bucket S3 vazio e não adicione workloads ao laboratório.
- Nunca faça commit de `.demo-state/`, Terraform gerado, relatórios,
  credenciais ou identificadores reais da conta.
- Nunca execute `terraform apply` durante o demo.
- Exclua o laboratório logo após a validação e confirme zero recursos restantes.

## Arquivos incluídos

```text
examples/demo/
├── README.md
├── README-pt.md
├── config/
│   ├── environments.conf.example
│   └── modularization.conf.example
├── validate-demo-readiness.sh
├── create-demo-resources.sh
└── delete-demo-resources.sh
```

O manifesto ignorado `.demo-state/resources.tsv` é criado localmente. A limpeza
usa sua conta, região, prefixo e IDs exatos e preserva o manifesto sempre que
não consegue comprovar a ausência dos recursos.

## Executar o demo

Na raiz do repositório `tf-importer`:

```bash
cp examples/demo/config/environments.conf.example config/environments.conf
cp examples/demo/config/modularization.conf.example config/modularization.conf

export AWS_PROFILE=<profile-de-credencial-temporária>
export AWS_REGION=<região-do-demo>

aws sts get-caller-identity
./examples/demo/validate-demo-readiness.sh
./examples/demo/create-demo-resources.sh

./tf-importer doctor demo
./tf-importer discover demo
./tf-importer pipeline demo

./examples/demo/delete-demo-resources.sh
```

A criação exige `CREATE`; a limpeza exige `DELETE`. O resultado Terraform
aceito é:

```text
N to import, 0 to add, 0 to change, 0 to destroy
```

Interrompa a execução se o plano propuser qualquer add, change ou destroy.

## Documentação detalhada

- [Arquitetura do demo](../../docs/demo/AWS_DEMO_ARCHITECTURE.md)
- [Runbook completo](../../docs/demo/DEMO_RUNBOOK.md)
- [Guia de primeiros passos](../../docs/GETTING_STARTED-pt.md)

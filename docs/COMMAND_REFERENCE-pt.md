# Referência de comandos

[English](COMMAND_REFERENCE.md)

Os targets documentados do `make` são os entrypoints suportados do produto.
Use `./tf-importer` diretamente ao integrar a CLI em outro fluxo.

## Sintaxe comum

```bash
make <target> ENV=<dev|qa|prd>
make <target> ACCOUNT=<chave-de-conta-registrada> ENV=<dev|qa|prd>
```

`ACCOUNT` é opcional. Quando informado, seleciona uma conta registrada, seu
profile, ambientes permitidos, caminhos de execução e escopo do backend.

## Targets do Make

| Comando | Finalidade | Comportamento na AWS e saída |
| --- | --- | --- |
| `make version` | Exibe a versão instalada. | Offline; não cria saída. |
| `make doctor ENV=dev` | Verifica ferramentas, credenciais, região, conta e conectividade. | Somente leitura; não gera Terraform. |
| `make validate ENV=dev` | Executa a mesma validação completa. | Somente leitura; não gera Terraform. |
| `make discover ENV=dev` | Inventaria recursos regionais suportados. | Descoberta AWS somente leitura; grava inventário ignorado. |
| `make auto ENV=dev` | Descobre, classifica, mapeia IDs e gera imports. | Chamadas AWS somente leitura; grava artefatos ignorados. |
| `make build ENV=dev` | Gera e normaliza Terraform e executa o gate do plano. | Lê pela AWS provider; nunca aplica. |
| `make full ENV=dev` | Executa `auto` e `build`. | Para antes de split e modularização. |
| `make split ENV=dev` | Divide o Terraform validado em categorias. | Usa arquivos locais gerados. |
| `make plan ENV=dev` | Executa o gate de plano validado por conta. | Aceita apenas imports e zero outras ações. |
| `make pipeline ENV=dev` | Executa o fluxo single-account completo. | Produz roots validados; nunca aplica. |
| `make test` | Executa testes offline e de integridade. | Não autentica na AWS. |
| `make ci` | Executa testes e todos os gates estáticos. | Offline; não autentica na AWS. |

## Comandos da CLI

```bash
./tf-importer help
./tf-importer version
./tf-importer doctor [ambiente]
./tf-importer validate [ambiente]
./tf-importer discover <ambiente>
./tf-importer auto <ambiente>
./tf-importer build <ambiente>
./tf-importer split <ambiente>
./tf-importer analyze <ambiente>
./tf-importer plan <ambiente>
./tf-importer pipeline <ambiente>
```

A região não é aceita como override de linha de comando de forma intencional.
Altere `PROJECT_REGION` na configuração ignorada quando a região mudar.

## Logs e saída legível por sistemas

Mensagens de progresso e validação são enviadas para `stderr` e para
`logs/tf-importer.log`. O `stdout` permanece disponível para JSON ou Terraform.

- `LOG_LEVEL=DEBUG` habilita detalhes de diagnóstico.
- `LOG_CONSOLE=0` desabilita logs no console e mantém o arquivo de log.

## Escolhendo um comando

- Nova instalação: comece com `doctor` e depois use `pipeline`.
- Somente revisão de inventário: use `discover`.
- Geração antes da publicação por categoria: use `full`.
- Repetir a verificação final de segurança: use `plan`.
- Desenvolvimento: use `test` durante o trabalho e `ci` antes do commit.

Consulte [Primeiros passos](GETTING_STARTED-pt.md) para configuração e
[Arquitetura](ARCHITECTURE.md) para os estágios executados por `pipeline`.

# Primeiros passos

[English](GETTING_STARTED.md)

Este guia conduz um novo operador de um checkout limpo até a primeira execução
validada do `tf-importer`. Leia o [modelo de segurança](PRODUCT_CONTRACT.md)
antes de usar uma conta de produção.

## 1. Instale os pré-requisitos

- Ubuntu, Linux compatível ou WSL2
- Bash 5 ou mais recente
- AWS CLI 2 com credenciais temporárias
- Terraform `>= 1.5, < 2.0`
- Python 3.12 ou mais recente
- jq 1.6 ou mais recente
- curl e utilitários GNU de linha de comando

As versões suportadas e validadas estão em
[Compatibilidade](COMPATIBILITY.md).

## 2. Crie a configuração local

Na raiz do repositório:

```bash
cp config/environments.conf.example config/environments.conf
cp config/modularization.conf.example config/modularization.conf
```

Os dois arquivos de destino são ignorados pelo Git. Substitua todos os
placeholders antes de executar o importer.

Em `config/environments.conf`, defina o projeto, sua única região ativa e a
conta esperada para cada ambiente:

```bash
PROJECT_NAME=<nome-do-projeto>
PROJECT_REGION=<região-aws>

DEV_ACCOUNT_ID=<id-da-conta>
QA_ACCOUNT_ID=<id-da-conta>
PRD_ACCOUNT_ID=<id-da-conta>
```

`PROJECT_REGION` é a fonte única da região. O importer não usa a região padrão
da AWS CLI e não consulta outras regiões.

Um registro multi-account opcional pode selecionar uma chave neutra e um
profile AWS sem armazenar credenciais:

```bash
ACCOUNT_1_KEY=<chave-da-conta>
ACCOUNT_1_ID=<id-da-conta>
ACCOUNT_1_PROFILE=<profile-aws>
ACCOUNT_1_ENVIRONMENTS=dev,qa,prd
```

Em `config/modularization.conf`, defina o projeto IaC de destino:

```bash
DESTINATION_PROJECT_DIR=../<projeto-de-destino>
DESTINATION_TEMPLATE_DIR=templates/destination
MODULE_MAP_FILE=config/resource_module_map.json
COST_CENTER=<centro-de-custo>
TAGS_MODULE_SOURCE=../../../tag
STATE_BUCKET=<bucket-de-state>
STATE_KEY_PREFIX=<prefixo-do-state>
```

Os caminhos são resolvidos a partir da raiz do `tf-importer`. Se o destino não
existir, o pipeline o inicializa usando o template.

## 3. Confirme a identidade AWS

Use credenciais temporárias e verifique a conta antes de continuar:

```bash
aws sts get-caller-identity
make doctor ENV=dev
```

Se credenciais exportadas puderem sobrescrever o profile selecionado, remova-as
somente durante a chamada:

```bash
env -u AWS_ACCESS_KEY_ID \
    -u AWS_SECRET_ACCESS_KEY \
    -u AWS_SESSION_TOKEN \
    AWS_PROFILE=<profile-do-ambiente> \
    make doctor ENV=<ambiente>
```

O comando para se credenciais, conta, região, ferramentas ou conectividade não
corresponderem ao ambiente selecionado.

## 4. Execute o pipeline

```bash
make pipeline ENV=dev
```

Para um escopo multi-account registrado:

```bash
make pipeline ACCOUNT=<chave-da-conta> ENV=dev
```

O pipeline lê a AWS e grava artefatos locais ignorados. Ele nunca executa
`terraform apply`. Um resultado válido antes da adoção deve terminar com:

```text
N to import, 0 to add, 0 to change, 0 to destroy
```

Qualquer ação de add, change ou destroy é uma condição de falha. Não execute
apply para contorná-la.

## 5. Revise o resultado

- `work/` contém o Terraform intermediário gerado.
- `reports/` contém reconciliação detalhada e evidências dos planos.
- `logs/` contém os logs de execução.
- `DESTINATION_PROJECT_DIR` contém os roots de categoria independentes.

Esses artefatos podem conter dados reais da conta, valores, pacotes ou
identificadores de recursos e são privados por padrão. O importer nunca faz
stage, commit ou push deles.

Em seguida, consulte a [referência de comandos](COMMAND_REFERENCE-pt.md), a
[arquitetura](ARCHITECTURE.md) ou o
[demo AWS sanitizado](demo/DEMO_RUNBOOK.md).

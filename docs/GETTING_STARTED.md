# Getting Started

[Português](GETTING_STARTED-pt.md)

This guide takes a new operator from a clean checkout to the first validated
`tf-importer` pipeline. Read the [safety model](PRODUCT_CONTRACT.md) before
using a production account.

## 1. Install the requirements

- Ubuntu, compatible Linux, or WSL2
- Bash 5 or newer
- AWS CLI 2 with temporary credentials
- Terraform `>= 1.5, < 2.0`
- Python 3.12 or newer
- jq 1.6 or newer
- curl and GNU command-line utilities

The exact supported and validated versions are listed in
[Compatibility](COMPATIBILITY.md).

## 2. Create local configuration

From the repository root:

```bash
cp config/environments.conf.example config/environments.conf
cp config/modularization.conf.example config/modularization.conf
```

Both destination files are ignored by Git. Replace every placeholder before
running the importer.

In `config/environments.conf`, define the project, its only active region, and
the expected account for each environment:

```bash
PROJECT_NAME=<project-name>
PROJECT_REGION=<aws-region>

DEV_ACCOUNT_ID=<account-id>
QA_ACCOUNT_ID=<account-id>
PRD_ACCOUNT_ID=<account-id>
```

`PROJECT_REGION` is the single source of truth. The importer does not fall back
to the AWS CLI default region and does not scan other regions.

An optional multi-account registry can select a neutral account key and AWS
profile without storing credentials:

```bash
ACCOUNT_1_KEY=<account-key>
ACCOUNT_1_ID=<account-id>
ACCOUNT_1_PROFILE=<aws-profile>
ACCOUNT_1_ENVIRONMENTS=dev,qa,prd
```

In `config/modularization.conf`, define the generated IaC destination:

```bash
DESTINATION_PROJECT_DIR=../<destination-project>
DESTINATION_TEMPLATE_DIR=templates/destination
MODULE_MAP_FILE=config/resource_module_map.json
COST_CENTER=<cost-center>
TAGS_MODULE_SOURCE=../../../tag
STATE_BUCKET=<terraform-state-bucket>
STATE_KEY_PREFIX=<terraform-state-prefix>
```

Paths are resolved from the `tf-importer` root. If the destination does not
exist, the pipeline initializes it from the destination template.

## 3. Confirm the AWS identity

Use temporary credentials and verify the account before continuing:

```bash
aws sts get-caller-identity
make doctor ENV=dev
```

If exported access keys could override a selected profile, remove them only for
the command invocation:

```bash
env -u AWS_ACCESS_KEY_ID \
    -u AWS_SECRET_ACCESS_KEY \
    -u AWS_SESSION_TOKEN \
    AWS_PROFILE=<environment-profile> \
    make doctor ENV=<environment>
```

The command stops if credentials, account, region, tools, or connectivity do
not match the selected environment.

## 4. Run the pipeline

```bash
make pipeline ENV=dev
```

For a registered multi-account scope:

```bash
make pipeline ACCOUNT=<account-key> ENV=dev
```

The pipeline reads AWS and writes ignored local artifacts. It never runs
`terraform apply`. A successful pre-adoption result must end with:

```text
N to import, 0 to add, 0 to change, 0 to destroy
```

Any add, change, or destroy action is a failure condition. Do not apply the
plan to work around it.

## 5. Review the result

- `work/` contains intermediate generated Terraform.
- `reports/` contains detailed reconciliation and plan evidence.
- `logs/` contains execution logs.
- `DESTINATION_PROJECT_DIR` contains the independently operable category roots.

These artifacts can contain real account data, values, packages, or resource
identifiers and are private by default. The importer never stages, commits, or
pushes them.

Next, use the [command reference](COMMAND_REFERENCE.md) for individual stages,
the [architecture](ARCHITECTURE.md) to understand the pipeline, or the
[sanitized AWS demo](demo/DEMO_RUNBOOK.md) for a controlled lab.

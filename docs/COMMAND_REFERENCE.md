# Command Reference

[Português](COMMAND_REFERENCE-pt.md)

The documented `make` targets are the supported product entrypoints. Use
`./tf-importer` directly when integrating the CLI into another workflow.

## Common syntax

```bash
make <target> ENV=<dev|qa|prd>
make <target> ACCOUNT=<registered-account-key> ENV=<dev|qa|prd>
```

`ACCOUNT` is optional. When present, it selects one explicitly registered
account, profile, environment set, runtime path, and backend scope.

## Make targets

| Command | Purpose | AWS and output behavior |
| --- | --- | --- |
| `make version` | Print the installed version. | Offline; creates no output. |
| `make doctor ENV=dev` | Check tools, credentials, region, account, and connectivity. | Read-only; generates no Terraform. |
| `make validate ENV=dev` | Run the same complete preflight validation. | Read-only; generates no Terraform. |
| `make discover ENV=dev` | Inventory supported regional resources. | Read-only AWS discovery; writes ignored inventory. |
| `make auto ENV=dev` | Discover, classify, map IDs, and generate import blocks. | Read-only AWS calls; writes ignored artifacts. |
| `make build ENV=dev` | Generate and normalize Terraform, then run the plan gate. | Reads through Terraform; never applies. |
| `make full ENV=dev` | Run `auto` and `build`. | Stops before split and modularization. |
| `make split ENV=dev` | Split validated Terraform into categories. | Uses local generated files. |
| `make plan ENV=dev` | Run the account-validated plan gate. | Accepts imports only, with zero other actions. |
| `make pipeline ENV=dev` | Run the complete single-account workflow. | Produces validated category roots; never applies. |
| `make test` | Run offline unit and integrity tests. | Does not authenticate to AWS. |
| `make ci` | Run tests and every static validation gate. | Offline; does not authenticate to AWS. |

## CLI commands

```bash
./tf-importer help
./tf-importer version
./tf-importer doctor [environment]
./tf-importer validate [environment]
./tf-importer discover <environment>
./tf-importer auto <environment>
./tf-importer build <environment>
./tf-importer split <environment>
./tf-importer analyze <environment>
./tf-importer plan <environment>
./tf-importer pipeline <environment>
```

The region is intentionally not a command-line override. Change
`PROJECT_REGION` in the ignored environment configuration when the target
region changes.

## Logs and machine-readable output

Progress and validation messages go to `stderr` and to
`logs/tf-importer.log`. Command `stdout` remains available for generated JSON
or Terraform data.

- `LOG_LEVEL=DEBUG` enables diagnostic detail.
- `LOG_CONSOLE=0` disables console logs while retaining the log file.

## Choosing a command

- New installation: start with `doctor`, then `pipeline`.
- Inventory review only: use `discover`.
- Generation before category publication: use `full`.
- Repeat a final safety check: use `plan`.
- Project development: use `test` during work and `ci` before a commit.

See [Getting Started](GETTING_STARTED.md) for configuration and
[Architecture](ARCHITECTURE.md) for the stages executed by `pipeline`.

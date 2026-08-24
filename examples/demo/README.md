# Sanitized AWS Demo

[Português](README-pt.md)

This demo creates a small, private-by-default AWS lab outside Terraform and
then uses `tf-importer` to adopt it into an import-only Terraform baseline.

Use a dedicated non-production or personal test account. AWS charges may
apply. Review the architecture, permissions, pricing, and cleanup script before
creating anything.

## Safety Rules

- Use temporary credentials protected by MFA; never use root or long-lived
  access keys.
- Select one explicit `AWS_REGION` and confirm the active account.
- Review `delete-demo-resources.sh` before `create-demo-resources.sh`.
- Keep the S3 bucket empty and do not add workloads to the lab.
- Never commit `.demo-state/`, generated Terraform, reports, credentials, or
  real account identifiers.
- Never run `terraform apply` during the demo.
- Delete the lab immediately after validation and confirm zero remaining
  resources.

## Included Files

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

The ignored `.demo-state/resources.tsv` manifest is created locally. Cleanup
uses its exact account, region, prefix, and resource IDs and retains it whenever
absence cannot be proven.

## Run the Demo

From the `tf-importer` repository root:

```bash
cp examples/demo/config/environments.conf.example config/environments.conf
cp examples/demo/config/modularization.conf.example config/modularization.conf

export AWS_PROFILE=<temporary-credential-profile>
export AWS_REGION=<demo-region>

aws sts get-caller-identity
./examples/demo/validate-demo-readiness.sh
./examples/demo/create-demo-resources.sh

./tf-importer doctor demo
./tf-importer discover demo
./tf-importer pipeline demo

./examples/demo/delete-demo-resources.sh
```

Creation requires `CREATE`; cleanup requires `DELETE`. The accepted Terraform
result is:

```text
N to import, 0 to add, 0 to change, 0 to destroy
```

Stop if a plan proposes any add, change, or destroy action.

## Detailed Documentation

- [Demo architecture](../../docs/demo/AWS_DEMO_ARCHITECTURE.md)
- [Complete runbook](../../docs/demo/DEMO_RUNBOOK.md)
- [Project getting started guide](../../docs/GETTING_STARTED.md)

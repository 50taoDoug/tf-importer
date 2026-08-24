# AWS demo runbook

## Before the demo

Use temporary credentials, not root or a long-lived access key. Confirm MFA,
billing alerts, and the selected region. Review the cleanup
script before the creation script. The operator needs read/write/delete permissions
for the listed EC2 networking, S3, SSM, Logs, EventBridge, ECS, tagging, and STS
actions. `tf-importer` additionally needs its documented read/list/tagging and
Terraform Registry access.

Create ignored local configuration:

```bash
cp examples/demo/config/environments.conf.example config/environments.conf
cp examples/demo/config/modularization.conf.example config/modularization.conf
```

Replace placeholders locally. Never commit the files.

The demonstration S3 bucket is expected to remain empty. Do not upload objects
or create object versions in it. If objects or versions are added, bucket
deletion may fail; cleanup must report the failure clearly and retain the
manifest for review rather than broadening its deletion scope.

## 1. Create outside Terraform

```bash
export AWS_PROFILE=<temporary-credential-profile>
export AWS_REGION=<demo-region>
aws sts get-caller-identity
./examples/demo/validate-demo-readiness.sh
./examples/demo/create-demo-resources.sh
```

Read the account, region, principal, inventory, and cost warning, then type
`CREATE`. This is the only resource-creation phase and it contains no Terraform.

## 2. Run `tf-importer` read-only

Allow a few minutes for tag discovery if necessary.
The `demo` environment restricts Tagging API discovery to
`Project=tf-importer-demo`, keeping backend and unrelated account resources out
of the reproducible lab inventory. Other environments retain normal regional
discovery behavior.

```bash
./tf-importer doctor demo
./tf-importer discover demo
./tf-importer pipeline demo
jq . reports/tf-importer-demo/demo-account/demo/modularization_pipeline.json
```

Inspect the destination tree, native-preservation reasons, import blocks, dependency
report, and the real Terraform plan. Acceptance is exactly:

```text
N to import, 0 to add, 0 to change, 0 to destroy
```

Do not invent `N`, edit the result, or run `terraform apply`. If add/change/destroy
is nonzero, stop the run and investigate; do not apply.

## 3. Clean up manually

```bash
./examples/demo/delete-demo-resources.sh
```

Review the exact manifest-backed scope and type `DELETE`. Then rerun readiness or
use service-specific read commands to confirm absence. The cleanup validates that
the active account, region, and prefix match the creation manifest, retries AWS
post-delete checks, and removes that manifest only after exact-ID and tag queries
both report zero resources. Any remaining resource or unverifiable result produces
a nonzero exit and retains the manifest for another cleanup attempt.
This preserves the exact manifest-based, account/region/prefix, and
tag-validated cleanup boundary. It does not recursively empty the bucket.

## Cost review

Check region pricing for API requests, S3 metadata/storage, Parameter Store tier,
CloudWatch Logs retention/ingestion, EventBridge events, ECS workloads, data
transfer, and public IPv4. The script creates no workload, event target, object, log
event, public IP, or paid gateway. The demo is designed to minimize cost, but AWS
charges may still apply depending on region, account pricing, and execution duration.

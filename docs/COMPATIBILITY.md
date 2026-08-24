# Compatibility

## Supported Runtime

`tf-importer` supports Linux and WSL2 environments with:

| Component | Supported | Validated |
| --- | --- | --- |
| Terraform CLI | `>= 1.5, < 2.0` | `1.15.7` |
| AWS provider | `6.x` | `6.54.0` |
| AWS CLI | `2.x` | `2.35.15` |
| Bash | `>= 5.0` | `5.2.21` |
| Python | `>= 3.12` | `3.12.3` |
| jq | `>= 1.6` | `1.7` |
| curl | Available in `PATH` | `8.5.0` |
| GNU awk | Available in `PATH` | `5.2.1` |
| GNU sed | Available in `PATH` | `4.9` |
| GNU grep | Available in `PATH` | `3.11` |
| GNU findutils | Available in `PATH` | `4.9.0` |
| GNU coreutils | Provides `mktemp` and `realpath` | `9.4` |
| Operating system | Ubuntu or compatible Linux | Ubuntu `24.04` on WSL2 |

Native Windows shells are not supported. Use WSL2 when running on Windows.
Generated root modules enforce Terraform `>= 1.5.0, < 2.0.0` and AWS provider
`>= 6.54.0, < 7.0.0` through `versions.tf`.

Runtime also requires outbound HTTPS access to AWS APIs, pre-signed Lambda
download URLs, and the Terraform provider registry.

## Development and Validation Tools

These tools are not required to invoke `./tf-importer` directly, but are
required for the complete local validation workflow:

| Component | Supported | Validated |
| --- | --- | --- |
| Git | Current maintained version | `2.43.0` |
| GNU Make | Current maintained version | `4.3` |
| ShellCheck | `>= 0.9` | `0.9.0` |

## Continuous Integration

GitHub Actions validates the project on Ubuntu 24.04 with:

- Python 3.12 through `actions/setup-python@v6`;
- Terraform 1.15.7 through `hashicorp/setup-terraform@v4`;
- ShellCheck and jq from the Ubuntu repositories;
- repository checkout through `actions/checkout@v6`.

CI is static and does not authenticate to AWS. Real discovery and import-only
plans remain controlled acceptance tests against an explicitly configured AWS
account and region.

## Provider Compatibility

The accepted PRD baseline was generated and planned with AWS provider 6.54.0.
Provider upgrades must repeat the clean-destination acceptance test because
Terraform-generated configuration is provider-version sensitive.

## Validated AWS Resource Coverage

The accepted DEV, QA, and PRD baselines validate end-to-end import and
modularization contracts for these 31 Terraform resource types:

- networking: `aws_vpc`, `aws_subnet`, `aws_route_table`,
  `aws_security_group`, `aws_internet_gateway`, `aws_vpc_dhcp_options`,
  `aws_vpc_endpoint`, `aws_vpc_endpoint_service`, `aws_eip`, `aws_flow_log`,
  `aws_default_network_acl`, and
  `aws_ec2_transit_gateway_vpc_attachment`;
- containers and delivery: `aws_ecr_repository`, `aws_ecs_cluster`,
  `aws_ecs_service`, and `aws_ecs_task_definition`;
- load balancing: `aws_lb`, `aws_lb_listener`, and `aws_lb_target_group`;
- identity and protection: `aws_iam_policy`, `aws_iam_instance_profile`,
  `aws_kms_key`, and `aws_secretsmanager_secret`;
- storage and messaging: `aws_s3_bucket` and `aws_sns_topic`;
- runtime and integration: `aws_lambda_function`, `aws_ssm_parameter`,
  `aws_cloudwatch_event_rule`, and `aws_cloudwatch_log_group`;
- orchestration and backup: `aws_cloudformation_stack` and
  `aws_backup_vault`.

This is validated type-level coverage, not universal variant coverage. Contract
conditions intentionally preserve some historical, ambiguous, default,
service-managed, or otherwise unsafe variants as native Terraform. A provider
upgrade or a previously unseen schema variant requires new acceptance
evidence.

The ARN discovery map recognizes 63 Terraform resource candidates. That larger
number describes classification capability only. It must not be presented as
63 end-to-end supported resource types. Untagged resources and resources absent
from the configured discovery sources may not be observed at all.

## Release Validation

A release candidate is accepted only when:

- all automated tests pass;
- Bash, ShellCheck, Python, JSON, and Terraform formatting checks pass;
- no runtime artifacts are tracked;
- no automated apply entrypoint exists;
- a real plan contains imports only;
- source and destination import/resource counts match;
- no staging directory remains after success, failure, or interruption.
- GitHub Actions are pinned to verified full commit SHAs;
- Markdown links, release metadata, tracked content, and a clean-checkout smoke
  test pass without AWS credentials.

See [Release Readiness](RELEASE_READINESS.md) for the sanitization, standalone,
real-AWS acceptance, and owner-approval boundaries.

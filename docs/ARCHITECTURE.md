# Architecture

The permanent automation boundary and definition of done are specified in
[`PRODUCT_CONTRACT.md`](PRODUCT_CONTRACT.md).

`tf-importer` discovers existing AWS resources in one explicitly configured
region and produces safe Terraform import roots. It never runs
`terraform apply`.

## Pipeline

```text
environment and account validation
  -> regional AWS discovery
  -> exclusions and ARN mapping
  -> Terraform import blocks
  -> terraform plan -generate-config-out
  -> generated configuration cleanup
  -> SSM and Lambda snapshot enrichment
  -> failed and orphan import pruning
  -> terraform fmt and validate
  -> import-only source plan
  -> dependency analysis
  -> category split
  -> module-call generation per category
  -> resource/import parity per category
  -> import-only plan per category
  -> category-root publication
  -> discovered-resource and import-candidate reconciliation
  -> consolidated reports and destination documentation
```

## Layers

- `tf-importer`: CLI entrypoint.
- `scripts/core/`: bootstrap, dispatching, logging, version, and execution
  context.
- `scripts/commands/`: command orchestration.
- `scripts/providers/aws/`: read-only AWS discovery and resource filters.
- `scripts/terraform/`: Terraform generation, cleanup, analysis, split, and
  modularization helpers.
- `config/`: project, region, account, exclusion, and ARN mapping settings.

## Safety Boundaries

- `PROJECT_REGION` is the only AWS region queried.
- The active AWS account must match the selected environment.
- AWS operations are read-only.
- Every accepted plan must contain imports only:
  `N to import, 0 to add, 0 to change, 0 to destroy`.
- Unsupported resources remain native Terraform resources.
- Resource identities, runtime data, SSM values, Lambda packages, plans,
  detailed reports, credentials, private configuration, and Terraform state
  are never committed.
- Only sanitized counts by environment, service, and outcome are published to
  the destination documentation.
- Applying infrastructure is a separate, manual decision outside this project.

## Destination Model

The final IaC repository separates reusable modules from independently
operated Terraform roots:

```text
example-iac/
├── modules/<capability>/
├── tag/
└── terraform/<environment>/<category>/
    ├── backend.tf
    ├── provider.tf
    ├── versions.tf
    ├── main.tf
    └── imports_generated.tf
```

Each environment/category directory has its own backend state and can be
initialized and planned independently. Supported resources call reusable
modules; supported tag inputs consume the shared tag module while preserving
the exact observed brownfield tags. Unsupported types remain native.

References inside one category root may use direct module outputs. A
cross-category value remains the exact imported literal until an explicit,
reviewed output and remote-state contract exists; Terraform cannot reference a
module in another root directly.

The ignored `work/`, `output/`, `reports/`, and `logs/` trees are runtime
workspaces, not the final IaC project.

## Multi-Account Scope

The Example destination remains accepted at
`terraform/<environment>/<category>/`. The next multi-account destination uses
the generalized scope:

```text
terraform/<account-key>/<environment>/<category>/
```

`account-key` is a neutral alias explicitly defined in the private account
registry; it is never inferred as `platform` or `application`. Each account,
environment, and category remains an independently operated Terraform root and
state. Cross-account relationships are documented and attributed separately;
they do not create a shared multi-account state.

Cross-account analysis is inventory, not remediation. The importer may inspect
and report policies, trust relationships, references, ownership, and observed
gaps, but it never changes them. Any AWS correction is always performed
explicitly by the user outside the importer.

Final account-scoped publication deterministically scans generated Terraform
resource bodies for references to other IDs in the private account registry.
It records consumer/owner attribution, target service, Terraform address,
attribute, disposition, user-review action, and a reference fingerprint in
the ignored
`reports/<project>/<account>/<environment>/cross_account_relationships.json`
ledger. Observations are deduplicated and reconciled before a counts-only
summary is written to
`docs/inventory/<account>/<environment>-cross-account.md`. The summary contains
no account IDs, resource identities, Terraform addresses, or fingerprints.

No operational decision depends on AI. Discovery, classification, generation,
reconciliation, and acceptance use deterministic code and machine-verifiable
gates. A destination is not published when Terraform validation fails, parity
is incomplete, an import is unaccounted for, or a plan proposes add, change,
or destroy.

The `make` workflow is the product boundary. Its accepted output is Terraform
that can be initialized, planned, and operated without a separate
interpretation step. Anything representable by Terraform and the pinned
provider belongs in the generated destination. Manual disposition is reserved
for a documented provider/Terraform impossibility, never for an importer gap.

The account registry is optional for legacy single-account projects and uses
numbered entries in `config/environments.conf`:

```text
ACCOUNT_1_KEY=<account-key>
ACCOUNT_1_ID=<account-id>
ACCOUNT_1_PROFILE=<aws-profile>
ACCOUNT_1_ENVIRONMENTS=dev,qa,prd
```

Only the profile name belongs in this configuration. Access keys, secret keys,
session tokens, and passwords remain outside the repository.

Account-specific overrides for `STATE_BUCKET`, `STATE_KEY_PREFIX`,
`COST_CENTER`, `TAGS_MODULE_SOURCE`, and `RESOURCE_EXPLORER` may be placed
beside the account entry.
The selected account override wins; when absent, the value falls back to
`config/modularization.conf`.

## Inventory Accountability

Every resource returned by the regional discovery is retained in an ignored
resource-level ledger. The pipeline classifies it as:

- excluded by an explicit generation policy;
- skipped because it cannot be imported independently;
- unmapped to a Terraform resource type;
- mapped to one or more import candidates.

Every generated import candidate must then have exactly one final outcome:
failed remote read, orphan import, reusable-module call, or native Terraform.
The pipeline stops if discovered-resource counts or import-candidate addresses
do not reconcile.

The detailed ledger is available as JSON and a Markdown mirror at
`reports/<project>/<environment>/inventory_coverage.{json,md}`. The destination
receives only a sanitized counts-only summary under
`docs/inventory/<environment>.md`. Excluded, skipped, and unmapped resources
remain reported even though they are not generated as Terraform.

Resource Explorer is a complementary, opt-in source controlled by
`RESOURCE_EXPLORER_ENVIRONMENTS` in ignored configuration. When enabled, its
observations are merged with the Tagging API by ARN and the detailed ledger
retains the `sources` list for each observation.

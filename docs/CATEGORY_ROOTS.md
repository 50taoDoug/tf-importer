# Environment and Category Root Architecture

## Decision

Every environment/category pair is an independent Terraform root and state:

```text
example-iac/
├── modules/
├── tag/
└── terraform/
    ├── dev/
    │   ├── network/
    │   ├── ecs/
    │   └── ...
    ├── qa/
    └── prd/
```

Each category directory contains `backend.tf`, `provider.tf`, `versions.tf`,
`main.tf`, and `imports_generated.tf`. Modules remain organized by reusable
capability under `modules/`; `tag/` is the shared tags module.

## State Boundary

Backend keys include both the environment and category:

```text
<state-key-prefix>/<environment>/<category>/terraform.tfstate
```

This permits an operator to initialize, plan, and, outside `tf-importer`,
manually apply only the affected category. For example, a network-only change
is operated from `terraform/prd/network/` and does not include ECS, Lambda, or
other category resources in that plan.

## Reference Boundary

Direct Terraform references are valid only inside one category root. The
generator may replace a literal with a module output when:

1. the literal exactly matches a unique imported identity;
2. the target contract declares the output;
3. the consumer contract allows that reference;
4. source and target are generated in the same category root;
5. the category plan remains import-only.

Values crossing category roots remain exact brownfield literals until a
separate, explicit output and `terraform_remote_state` contract is reviewed.
This avoids hidden state coupling and permits independent category operation.

## Brownfield Tags

Imported resources preserve their observed tags exactly. For resource types
with tag support, the root calls the shared tag module and merges only missing
defaults without overriding observed values. The tag module is shared code; it
does not create a separate Terraform root or backend.

## Publication Gates

- Generate each category in restricted temporary staging.
- Preserve source/destination resource and import parity.
- Reject missing and orphan imports.
- Run formatting, validation, and an import-only plan for every category.
- Publish a category only after its gates pass.
- Preserve unsupported resources as native Terraform.
- Reconcile every discovered resource and generated import candidate in the
  ignored inventory ledger.
- Publish only sanitized inventory counts to destination documentation.
- Remove legacy environment-root Terraform files only after all category
  publications succeed.
- Never run `terraform apply`.

## Consequences

- Categories have independent lifecycle, ownership, blast radius, and state.
- Cross-category composition must be explicit and may require operational
  ordering.
- The consolidated report sums category metrics; it is not itself a Terraform
  root or aggregate plan.
- A single `main.tf` containing all environment resources is not a supported
  destination layout.

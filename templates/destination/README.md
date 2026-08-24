# Generated Terraform Project

This project is created automatically by `tf-importer`.

During modularization, this placeholder is replaced with project-specific
documentation generated from the validated aggregate report.

## Structure

- `config/` contains the resource-to-module mapping.
- `modules/` contains reusable Terraform modules.
- `tag/` contains the shared tagging module.
- `terraform/<environment>/<category>/` contains independently validated root
  configurations.

Each category has its own backend state. Generated roots are published only
after Terraform validation and a category plan with zero add, change, or
destroy actions.

`tf-importer` never runs `terraform apply`.

Sanitized discovery-to-Terraform reconciliation is published under
`docs/inventory/`. Detailed resource identities remain in ignored runtime
reports.

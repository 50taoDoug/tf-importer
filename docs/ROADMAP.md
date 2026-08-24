# Public Roadmap

`tf-importer` will continue evolving around a small set of public priorities:

- expand validated AWS resource coverage;
- improve deterministic discovery and import-ID handling;
- strengthen reconciliation, parity, and import-only plan evidence;
- mature reusable Terraform module contracts and dependency references;
- improve multi-account operation without weakening account and region guards;
- keep generated account artifacts and credentials private by default.

Capabilities are documented as supported only after end-to-end acceptance against
the pinned Terraform and AWS provider constraints. Priorities may change as AWS and
the provider evolve; this roadmap is directional and does not promise release dates.

The permanent safety boundary remains unchanged: `tf-importer` reads existing AWS
infrastructure and prepares Terraform adoption artifacts, but never runs
`terraform apply`.

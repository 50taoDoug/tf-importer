# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Added

- Added release-metadata, Markdown-link, tracked-content, and clean-checkout CI
  gates without AWS access or additional Python dependencies.
- Added CODEOWNERS, GitHub Actions dependency updates, pull request guidance,
  sanitized issue forms, and a private-vulnerability reporting route.
- Added a bilingual release-readiness checklist that preserves explicit approval
  for version, tag, release, merge, and visibility decisions.

### Security

- Pinned every GitHub Action to a verified full commit SHA while documenting the
  corresponding major version.
- Disabled persisted checkout credentials, bounded CI runtime, disabled AWS
  instance-metadata discovery, and rejected AWS credential variables in offline
  validation.
- Added regression coverage for the CI supply-chain and publication-readiness
  boundaries.

### Fixed

- Corrected S3 and ECS tag payloads, collision-safe bucket suffix generation,
  and partial-creation rollback in the public AWS demo.
- Made demo cleanup idempotent across deleted EC2 identifiers, missing
  EventBridge resources, untagged empty-bucket recovery, and asynchronous ECS
  tag-index convergence.
- Added exact-ID, active-tag, deterministic-name, and manifest-absence cleanup
  evidence.
- Enabled the registered `demo` environment, isolated its discovery to the
  lab project tag, and restored the destination-project fields in the demo
  modularization example.

### Validation

- Completed a real 13-resource AWS demonstration with an import-only plan of
  13 imports, zero additions, zero changes, and zero destructions.
- Completed manifest-scoped cleanup with zero exact, active-tagged, or named
  resources remaining; 87 automated tests and all CI gates passed.

## [1.0.0] - 2026-07-29

### Documentation

- Added the public security policy, contribution guide, and Contributor
  Covenant-based code of conduct.
- Added aligned README navigation, guarded quick starts, community links, and
  the product contract and AWS demo documentation links.
- Documented that the demonstration S3 bucket must remain empty and that
  cleanup fails closed instead of expanding deletion scope.
- Established the permanent product automation contract: documented `make`
  entrypoints must produce deterministic, ready-to-use Terraform without AI
  as an operational dependency.
- Restricted manual disposition to demonstrated Terraform/provider
  limitations and kept all AWS remediation as an explicit user action.
- Established mandatory import parity, import-only plan, and deterministic
  generation gates.
- Recorded the accepted DEV and PRD partial-modularization baseline and the
  decision to implement dependency reference rewriting before expanding module
  coverage.
- Adopted one independently operated Terraform root and state per
  environment/category.
- Recorded that the attempted one-root-per-environment publication was
  rejected and superseded by the category-root architecture.

### Added

- Added deterministic cross-account relationship attribution, reconciliation,
  private evidence, and counts-only destination summaries.
- Added a portable GitHub Actions workflow for the public repository.
- Added account-scoped multi-account generation and deterministic documentation
  paths.
- Added private-by-default Git rules for generated Terraform and destination
  inventory summaries, with publication available only through an explicit
  user override for a reviewed path.
- Added module contract schema 2 with reusable module paths, import targets,
  outputs, reference consumers, selection rules, and brownfield tag behavior.
- Added auditable dependency edges and deterministic exact-identity reference
  rewriting.
- Added category report totals for shared-tag consumers and rewritten
  references.
- Added a detailed ignored inventory ledger that records every discovered
  resource, its classification reason, generated import target, and final
  outcome.
- Added sanitized destination inventory summaries with counts by environment,
  AWS service, and outcome.

### Validation

- Accepted the DEV category destination with 365 matching resources/imports,
  292 module calls, 73 native Task Definitions, and import-only category plans.
- Accepted the QA category destination with 270 matching resources/imports,
  268 module calls, two native Task Definitions, and 15 import-only category
  plans.
- Accepted the PRD category destination with 257 matching resources/imports,
  256 module calls, one historical native Task Definition, 256 shared-tag
  consumers, 96 valid within-category rewritten reference occurrences, and 15
  import-only category plans.

### Changed

- Increased modularization coverage while preserving unsupported and
  policy-excluded resources as native Terraform.
- Rewrote 272 exact dependency occurrences in DEV and 33 in PRD while
  preserving equivalent remote values.
- Changed the end-to-end pipeline to publish one validated Terraform root and
  backend state per environment/category.
- Updated generated destination documentation for independent category
  operation.
- Made policy exclusions, independently non-importable resources, and unmapped
  resources reporting outcomes instead of invisible generation omissions.

### Safety

- Replaced real project aliases and AWS account IDs in public documentation
  with explicit fictitious examples and added a regression test that rejects
  non-approved 12-digit account IDs in documentation.
- Removed private environment and modularization configuration from the Git
  index while preserving the ignored local files and tracked fictitious
  examples.
- Removed previously tracked real-account Terraform and inventory output from
  the Git index while preserving every local file.
- Ensured destination preparation applies private-by-default Git exclusions to
  both new and existing destination projects.
- Confirmed that `tf-importer` never stages, commits, or pushes generated
  account content.
- Added fail-closed reconciliation for every discovered resource and generated
  import candidate.
- Kept resource identities and classification reasons in ignored runtime
  reports; destination documentation receives counts only.

### Fixed

- Removed the unsupported unified preview/publication command and
  environment-only backend generator.
- Ensured successful category publication removes only the known root-level
  Terraform files and package directory left by the rejected unified layout.

## [0.2.1] - 2026-07-25

### Added

- Expanded `doctor` checks for all runtime commands, supported versions, GNU
  utilities, AWS account and region validation, Terraform Registry
  connectivity, and optional development tools.
- Automated coverage for version checks, doctor failures, existing destination
  preservation, and CI operation without a generated destination.

### Fixed

- Allowed CI to run from a clean checkout when the ignored `example-iac`
  destination is absent.
- Corrected the documented executable path from `bin/tf-importer` to
  `./tf-importer`.
- Removed the unused legacy AWS credential-check helper.
- Canonically sorted generated resource and import blocks by Terraform address,
  eliminating provider-order noise between otherwise identical runs.

### Validation

- Recreated a clean PRD destination in 941.62 seconds with 257 matching source
  and destination imports, 40 modularized resources, 217 native resources, 15
  validated categories, and no remaining staging directories.
- Confirmed every aggregate and category plan contained zero add, change, and
  destroy actions.
- Confirmed controlled invalid-credential and unavailable-registry scenarios
  return failures.

### Documentation

- Documented the `tests/` directory, offline test boundaries, current coverage,
  local execution, CI differences, and contribution rules.
- Completed the runtime and development prerequisites with curl, GNU command-line
  utilities, Git, Make, ShellCheck, operating-system support, and outbound
  network requirements.
- Synchronized the Portuguese README with the primary documentation, including
  the safety model, destination configuration, complete pipeline, reports, and
  deterministic output.

## [0.2.0] - 2026-07-25

### Added

- End-to-end `pipeline` command for discovery, import generation, configuration
  cleanup, dependency analysis, category split, modularization, validation, and
  destination publication.
- Canonical destination template with repository metadata, resource-to-module
  mapping, reusable Terraform modules, and the shared tag module.
- Safe downstream category modularization with temporary staging directories
  and atomic publication after successful validation.
- Consolidated `modularization_pipeline.json` report with source, destination,
  modularized, preserved-native, processed, and skipped resource counts.
- Final destination README generated from the aggregate report, including AWS
  context, per-category import counts, validation guarantees, and safe usage.
- Dependency analysis based on references found in generated Terraform
  configuration.
- S3 backend generation with native state locking through `use_lockfile`.
- Account-validated standalone `plan` command that rejects non-import-only
  results.
- Automated integrity tests for CLI loading, destination module mappings,
  generated documentation, runtime paths, and the absence of an apply
  entrypoint.
- Real-time terminal progress with numbered pipeline stages, discovery page
  updates, and persistent file logging without contaminating command output.
- GitHub Actions CI for tests, Bash, ShellCheck, Python, JSON, Terraform
  formatting, safety rules, runtime tracking, and whitespace validation.
- A documented runtime and CI compatibility matrix.

### Changed

- Standardized project source, CLI messages, and public documentation in
  English.
- Made `PROJECT_REGION` the single source of truth for AWS discovery, generated
  providers, enrichment reads, and backend generation.
- Made `PROJECT_NAME` configurable and used it consistently in generated paths
  and destination tagging.
- Preserved unsupported resource types as native Terraform resources instead
  of dropping them during modularization.
- Enforced import-only plans for the generated source and every published
  destination category.
- Moved the intermediate Terraform workspace from
  `terraform/environments/<project>/<environment>` to
  `work/<project>/<environment>` so it cannot be mistaken for the final IaC
  project.
- Removed reproducible Terraform providers and obsolete project scaffolding
  from version control.
- Consolidated runtime ignore rules for workspaces, discovery output, reports,
  logs, Terraform state, Lambda packages, and Python caches.
- Archived obsolete design documentation and removed the completed session
  handoff.
- Removed unused shell modules, functions, constants, and the unused `unzip`
  dependency.

### Fixed

- Validated the configured AWS account before discovery and Terraform
  operations.
- Prevented accidental multi-region discovery and AWS CLI region fallback.
- Pruned failed and orphan imports while requiring source and destination
  resource/import counts to match.
- Prevented categories with add, change, or destroy actions from being
  published to the destination project.
- Removed project-specific defaults from the reusable destination template.
- Sorted discovered resources by ARN so repeated runs produce deterministic
  import and destination configuration ordering.
- Guaranteed staging cleanup on normal failure, `SIGINT`, `SIGTERM`, and
  process exit, restricted to validated `.tf-importer` temporary paths.
- Enforced Terraform and AWS provider compatibility constraints in generated
  source and destination root modules.

### Security

- Removed every project-level `terraform apply` entrypoint; applying imported
  infrastructure remains a separate manual decision.
- Kept generated account data, SSM values, Lambda packages, plans, reports,
  state, and intermediate Terraform configuration outside version control.
- Added explicit account and region safety boundaries to standalone and
  pipeline workflows.

### Validation

- Completed a clean PRD destination regeneration with 257 imports, 40
  modularized resources, and 217 preserved native resources.
- Confirmed the aggregate and every category plan contained zero add, change,
  and destroy actions.
- Added Bash, ShellCheck, Python, JSON, Terraform formatting, Git diff, and
  automated unit/integrity checks to the final validation workflow.

## [0.1.0] - Foundation

### Added

- Initial repository structure.
- Base documentation, scripts, Terraform directories, inventory, and reports.
- Terraform-oriented `.gitignore`.

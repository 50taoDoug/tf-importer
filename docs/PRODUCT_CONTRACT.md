# Product Automation Contract

## Status

- State: accepted.
- Effective date: 2026-07-29.
- Scope: every supported `tf-importer` and `make` workflow.

## Product Boundary

The documented `make` targets are the supported product entrypoints. A
successful workflow must produce independently operable, ready-to-use
Terraform rather than a draft that requires AI or subjective interpretation.

The destination includes, when applicable:

- Terraform resources and reusable module calls;
- import blocks with exact source/destination parity;
- provider and backend configuration;
- the provider dependency lock file;
- independently operable account, environment, and category roots;
- sanitized inventory and reconciliation summaries;
- machine-verifiable validation and plan evidence.

## Accepted Decisions

### 1. No AI in the operational workflow

AI may assist project development, but it is not a runtime dependency and does
not analyze, approve, repair, or interpret an import. Operational decisions are
implemented as deterministic code and machine-verifiable gates.

### 2. Automate everything Terraform can represent

If Terraform and the pinned provider can represent and import a discovered
resource safely, the importer is responsible for generating it. Lack of a
current mapping is an importer backlog item, not a valid manual fallback.

Reusable modules are preferred when a complete contract exists. Otherwise, a
supported resource is preserved as native Terraform so it is not dropped.

### 3. Zero-error accepted output

Publication fails closed unless all applicable guarantees pass:

- every discovery outcome is classified;
- every import candidate has exactly one final outcome;
- source and destination resource/import counts match;
- no expected import is missing or orphaned;
- generated files pass `terraform fmt` and `terraform validate`;
- every pre-adoption plan contains imports only;
- every accepted pre-adoption plan has zero add, change, and destroy actions;
- every post-adoption plan has zero changes;
- account, environment, region, root, and backend scope are correct.

An error report is useful diagnostic evidence, but it is not a successful
Terraform deliverable.

### 4. Continuously reduce automatic-mode errors

The primary quality direction is to reduce deterministic failures and manual
intervention without weakening safety gates. Repeated failures should become:

- cleanup or normalization rules when the correction is deterministic;
- new resource mappings or native Terraform preservation;
- import-ID extraction support;
- explicit dependency/reference contracts;
- a deterministic reconciled ledger for references to other registered AWS
  accounts;
- regression tests based on the observed failure class;
- precise, structured failure reasons when safe automation is impossible.

Automation must never hide, discard, or silently reinterpret a resource merely
to make the pipeline pass.

### 5. Manual disposition has a narrow boundary

A resource may require manual disposition only when a documented limitation of
Terraform or the pinned provider makes safe representation or import
impossible. The report must record the limitation and the affected outcome.

Manual disposition is not acceptable for:

- generator defects;
- missing importer mappings;
- incomplete reconciliation;
- invalid Terraform;
- unexpected plan changes;
- ambiguous account or state ownership;
- a task that could be implemented deterministically.

### 6. AWS remediation belongs to the user

The importer inventories existing infrastructure and generates Terraform. It
does not correct live AWS resources, policies, trust relationships,
permissions, or application configuration. Findings are reported with evidence
and ownership; any remediation or infrastructure application is an explicit
user action outside the importer.

This boundary does not excuse generation errors. The generated Terraform must
faithfully represent the accepted brownfield state without silently changing
it.

### 7. Generated account projects are private by default

Generated Terraform and inventory documents may describe real accounts or
contain sensitive values. Destination `terraform/` and `docs/inventory/`
content is ignored by Git by default. The importer never stages, commits, or
pushes it.

Publication is an explicit user decision made only after complete review and
sanitization. The user may override the ignore rule for an exact approved path
with `git add -f`; no pipeline command makes that decision automatically.

## Definition of Done

A workflow is complete only when:

1. the documented `make` command finishes successfully;
2. reconciliation and source/destination parity are complete;
3. every generated root passes formatting and validation;
4. every plan passes the applicable import-only or zero-change gate;
5. the destination is ready for normal Terraform operation;
6. any remaining manual item cites a proven Terraform/provider limitation;
7. no AWS correction or apply was performed by `tf-importer`.

## Change Control

Changes may strengthen automation, coverage, diagnostics, or safety. They must
not weaken the zero-error gates, introduce AI as an operational dependency, or
expand manual disposition to cover importer defects.

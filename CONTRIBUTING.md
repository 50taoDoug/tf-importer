# Contributing to tf-importer

`tf-importer` is an AWS Infrastructure Adoption Framework for Terraform. It
builds deterministic, import-only Terraform baselines for existing resources;
contributions must preserve its account, region, and no-apply safety model.

## Development workflow

Install Git, GNU Make, Bash 5+, Python 3.12+, ShellCheck 0.9+, Terraform
`>= 1.5, < 2.0`, jq, and the GNU utilities listed in the README. AWS CLI 2 is
needed for operational work, but the test and CI suites are offline.

Create a focused branch from an up-to-date base:

```bash
git switch -c <type>/<short-description>
```

Before submitting a pull request, run:

```bash
make test
make ci
git diff --check
```

`make ci` requires ShellCheck and runs the complete project validation. For
focused checks, use `bash -n` and `shellcheck` on changed shell scripts and
`terraform fmt -check` on changed Terraform directories. Do not suppress a
real diagnostic merely to make a gate pass.

CI must run without AWS credential environment variables. It also validates
tracked content, relative Markdown links, release metadata, and basic CLI use
from a clean archived checkout. See the
[release-readiness checklist](docs/RELEASE_READINESS.md) before proposing a
version, tag, release, or visibility change.

## Code, documentation, and safety

- Write Bash compatible with Bash 5, use strict error handling where
  appropriate, quote expansions, and keep account/region boundaries explicit.
- Write Python 3.12 code with clear names, standard-library conventions,
  deterministic output, and no unnecessary dependencies.
- Add or update automated tests for every behavior change. Keep documentation,
  examples, configuration templates, and both READMEs synchronized when a
  public command, contract, or workflow changes.
- Never add an automated `terraform apply` entrypoint. Preserve import-only
  plan enforcement and fail closed on add, change, or destroy actions.
- Do not commit credentials, real account or resource identifiers, SSM values,
  Lambda packages, generated Terraform, plans, state, inventories, reports,
  logs, private configuration, or private local paths. Sanitize copied terminal
  output and use only clearly fictitious examples.

## Pull requests

Keep changes narrow and explain their purpose, safety impact, validation
performed, and any documentation or test updates. Link the relevant issue when
one exists. Avoid unrelated refactors, generated artifacts, and formatting
churn. Reviewers may request evidence that the public-tree audit passes and
that import-only behavior is unchanged.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
Report vulnerabilities through the private process in [SECURITY.md](SECURITY.md),
never through a public pull request or issue.

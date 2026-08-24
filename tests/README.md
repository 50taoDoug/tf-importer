# Automated Tests

The `tests/` directory contains offline unit and project-integrity tests for
`tf-importer`.

Tests must not:

- authenticate to AWS;
- access live AWS resources;
- run a real Terraform plan;
- modify infrastructure;
- require generated runtime files from `work/`, `output/`, or `reports/`.

## Running the Tests

From the `tf-importer` project root:

```bash
make test
```

This runs Python's standard `unittest` discovery:

```bash
python3 -m unittest discover -s tests -v
```

For the complete local CI validation, run:

```bash
make ci
```

`make ci` includes the automated tests plus Bash syntax, ShellCheck, Python
compilation, JSON parsing, Terraform formatting, offline credential isolation,
no-apply enforcement, tracked-content and Markdown-link audits, release metadata,
a clean-checkout smoke test, and Git whitespace checks.

## Current Coverage

`test_project.py` verifies:

1. Destination README generation includes operational context and counts.
2. Incomplete modularization reports are rejected.
3. The GitHub Actions workflow is static, read-only, and contains no AWS
   credentials.
4. The CLI loads its registered commands.
5. Destination module mappings point to existing modules.
6. Intermediate Terraform output uses `work/`.
7. Generated `versions.tf` files enforce supported Terraform and AWS provider
   versions.
8. Progress logs use `stderr` without contaminating command `stdout`.
9. AWS discovery is sorted by ARN before import generation.
10. Staging cleanup is restricted to validated temporary paths.
11. A `SIGTERM` removes active staging and exits with the expected status.
12. No automated Terraform apply entrypoint exists.
13. Version comparison accepts supported versions and rejects older versions.
14. A failed runtime check makes `doctor` return a failure status.
15. An existing destination project is preserved during bootstrap.
16. CI accepts a clean checkout where the generated destination does not exist.
17. Generated Terraform resources and imports are sorted by address.
18. Inventory accountability reconciles excluded, skipped, unmapped, failed,
    orphan, modularized, and native outcomes without publishing identities.

## Adding Tests

- Use Python's standard `unittest` library.
- Name test files `test_*.py`.
- Keep fixtures temporary by using `tempfile.TemporaryDirectory`.
- Use subprocesses for shell behavior that depends on signals or environment
  variables.
- Assert safety behavior explicitly, including expected failure paths.
- Keep all tests deterministic and independent of local AWS credentials.
- Run both `make test` and `make ci` before committing.

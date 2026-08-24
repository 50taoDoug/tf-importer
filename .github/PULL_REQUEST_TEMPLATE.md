## Summary

Describe the problem, the chosen solution, and any compatibility impact.

## Safety and validation checklist

- [ ] I ran the offline test suite with `make test`.
- [ ] I ran all static and integrity gates with `make ci`.
- [ ] I did not add or execute `terraform apply`.
- [ ] I did not add credentials, real account data, generated Terraform, state,
      plans, inventories, reports, Lambda packages, SSM values, or private paths.
- [ ] I updated the relevant English and Brazilian Portuguese documentation.
- [ ] I documented compatibility impact and preserved existing functionality.
- [ ] I assessed whether controlled real-AWS acceptance must be repeated; no AWS
      operation is part of this pull request or its CI.
- [ ] `VERSION`, `CHANGELOG.md`, and any proposed future release tag are
      consistent, or the remaining release decision is documented.

## Evidence

Provide exact offline test counts and gate results. Use only fictitious or
redacted identifiers. Never attach credentials, runtime output, or real-account
evidence to a public pull request.

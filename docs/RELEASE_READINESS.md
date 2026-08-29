# Release Readiness

[Português](RELEASE_READINESS-pt.md)

## Purpose

This checklist prepares a reviewed release candidate without authorizing a tag,
GitHub Release, visibility change, merge, or publication. Product changes remain
in the authoritative private source until they are sanitized and synchronized to
a clean standalone checkout.

## Current version decision

The owner approved `v1.0.1` on 2026-08-29 to close Phase 1. The current sanitized
public history contains no release tag, despite private records describing a tag
on a superseded publication history. Do not recreate or move `v1.0.0` on the
current history.

`VERSION`, `CITATION.cff`, and the changelog are aligned at `1.0.1`. Create the
annotated `v1.0.1` tag only after the exact synchronized commit passes every
gate, then publish the corresponding GitHub Release without moving the tag.

## Offline gates

Run without AWS credentials:

```bash
make test
make ci
```

The CI script must pass tests, Bash syntax, ShellCheck, Python compilation, JSON,
Terraform formatting, no-apply enforcement, credential isolation, tracked-file
and secret patterns, Markdown links, release metadata, clean-checkout smoke, and
Git whitespace. Record exact test counts; never infer or reuse stale results.

## Sanitization and standalone validation

1. Run the private denylist audit against the publishable source and complete
   reachable standalone history.
2. Synchronize through the reviewed private publication script.
3. Review every changed path and confirm that private documentation and runtime
   data are absent.
4. Validate from a clean standalone checkout with no AWS configuration.
5. Confirm the exact standalone commit and successful CI run.
6. Review accessible Actions history and logs before changing visibility.

Generated Terraform, state, plans, reports, inventories, Lambda packages, SSM
values, credentials, local configuration, and private identifiers are never
release artifacts.

## Real AWS acceptance boundary

Offline CI does not prove real discovery, provider behavior, import parity, or
cleanup. Repeat controlled AWS acceptance only when the change affects those
areas and the owner separately authorizes the account, region, temporary access,
resource creation, and cleanup. `tf-importer` never runs `terraform apply`.

An accepted plan contains imports only and zero add, change, or destroy actions.

## Final approval gate

Stop after presenting the reviewed diff, exact validation evidence, and remaining
risks. The owner must separately approve each merge, tag, GitHub Release,
visibility change, or external announcement.

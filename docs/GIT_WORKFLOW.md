# Git Workflow

The project uses short-lived feature branches and Conventional Commits.

## Branches

Create one branch for each cohesive change:

```bash
git switch -c feature/descriptive-name
```

Recommended prefixes:

- `feature/` for new capabilities.
- `fix/` for defect corrections.
- `docs/` for documentation-only work.
- `refactor/` for behavior-preserving restructuring.

## Commits

Use Conventional Commit messages:

```text
feat: add safe modularization fallback
fix: prevent generated JSON from receiving log output
docs: publish English documentation
```

Keep commits focused, validate the changed behavior, and never commit generated
AWS inventory, Terraform state, SSM values, Lambda packages, or plan reports.

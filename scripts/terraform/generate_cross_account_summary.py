#!/usr/bin/env python3
"""Publish a counts-only cross-account relationship summary."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def rows(values: dict[str, int], label: str) -> str:
    if not values:
        return f"| None observed | 0 |"
    return "\n".join(
        f"| `{key}` | {count} |" for key, count in sorted(values.items())
    )


def render(report: dict[str, Any]) -> str:
    if not report["reconciliation"]["complete"]:
        raise ValueError("refusing to publish an incomplete relationship summary")
    summary = report["summary"]
    return f"""# Cross-Account Relationship Summary

This sanitized summary contains counts only. Account IDs, resource identities,
Terraform addresses, attributes, and reference fingerprints remain in the
ignored runtime report.

## Reconciliation

| Stage | Count |
| --- | ---: |
| Observed candidates | {summary['observed_candidates']} |
| Unique relationships | {summary['unique_relationships']} |
| Duplicate observations removed | {summary['duplicates_removed']} |

Reconciliation status: **complete**.

## Relationships by service

| Service | Count |
| --- | ---: |
{rows(summary['by_service'], 'Service')}

## Relationships by disposition

| Disposition | Count |
| --- | ---: |
{rows(summary['by_disposition'], 'Disposition')}

The importer reports these relationships but never changes AWS policies,
trust, permissions, resource configuration, or application settings.
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument("destination_project", type=Path)
    parser.add_argument("account_key")
    parser.add_argument("environment")
    args = parser.parse_args()

    report = json.loads(args.report.read_text(encoding="utf-8"))
    output_dir = args.destination_project / "docs" / "inventory" / args.account_key
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / f"{args.environment}-cross-account.md").write_text(
        render(report),
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Publish a sanitized destination summary from a detailed coverage report."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ENVIRONMENTS = ("dev", "qa", "prd")


def service_rows(report: dict[str, Any]) -> str:
    rows = []
    for item in report["service_summary"]:
        rows.append(
            f"| `{item['service']}` | {item['discovered']} | "
            f"{item['excluded_by_policy']} | "
            f"{item['skipped_non_importable']} | {item['unmapped']} | "
            f"{item.get('controller_managed', 0)} | "
            f"{item.get('represented_by_parent', 0)} | "
            f"{item['generated_import_candidates']} | "
            f"{item['failed_remote_reads']} | {item['orphan_imports']} | "
            f"{item['terraform_resources']} | {item['modularized']} | "
            f"{item['native_terraform']} |"
        )
    return "\n".join(rows)


def render_environment(report: dict[str, Any], account_key: str = "") -> str:
    summary = report["summary"]
    environment = report["environment"]
    scope = f"{account_key}/{environment}" if account_key else environment
    report_scope = (
        f"{report['project']}/{account_key}/{environment}"
        if account_key
        else f"{report['project']}/{environment}"
    )
    controller_managed = summary.get("controller_managed_resources", 0)
    represented_by_parent = summary.get(
        "represented_by_parent_resources", 0
    )
    return f"""# {scope.upper()} Inventory Accountability

This sanitized summary records counts only. Resource identities, tags, values,
packages, plans, state, credentials, and private configuration remain in
ignored runtime reports produced by `tf-importer`.

## Reconciliation

| Stage | Count |
| --- | ---: |
| Discovered resources | {summary['discovered_resources']} |
| Excluded by explicit policy | {summary['excluded_by_policy']} |
| Skipped as non-importable | {summary['skipped_non_importable']} |
| Unmapped resources | {summary['unmapped_resources']} |
| Controller-managed resources | {controller_managed} |
| Resources represented by parent | {represented_by_parent} |
| Mapped AWS resources | {summary['mapped_resources']} |
| Generated import candidates | {summary['generated_import_candidates']} |
| Failed remote reads | {summary['failed_remote_reads']} |
| Orphan imports | {summary['orphan_imports']} |
| Final Terraform resources | {summary['terraform_resources']} |
| Modularized resources | {summary['modularized_resources']} |
| Native Terraform resources | {summary['native_terraform_resources']} |

Reconciliation status: **complete**.

## Coverage by AWS service

| Service | Discovered | Excluded | Skipped | Unmapped | Controller-managed | Represented by parent | Import candidates | Failed reads | Orphan imports | Terraform | Modularized | Native |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
{service_rows(report)}

“Excluded”, “skipped”, “unmapped”, “controller-managed”, and “represented by
parent” describe
Terraform-generation outcomes. Controller-managed resources are owned by an
external AWS controller such as EKS/Karpenter and are documented without being
placed under Terraform management. Resources represented by a parent are
preserved inside another Terraform resource, such as inline Security Group
rules, and are not dropped.
Failed reads and orphan imports were mapped but did not reach the final
Terraform destination. “Native” resources are managed by Terraform without a
reusable module; they are not dropped.

All resources and their individual reasons remain visible in the detailed
ignored report:

```text
reports/{report_scope}/inventory_coverage.json
```
"""


def render_detailed_report(report: dict[str, Any]) -> str:
    rows = []
    for resource in report["resources"]:
        targets = resource.get("terraform_targets", [])
        if targets:
            target_text = "<br>".join(
                f"`{target['address']}` — {target['outcome']} — "
                f"{target['outcome_reason']}"
                for target in targets
            )
        else:
            target_text = "—"
        rows.append(
            f"| `{resource['arn']}` | `{resource['service']}` | "
            f"`{resource['classification']}` | `{resource['action']}` | "
            f"{resource['reason']} | {target_text} |"
        )
    rendered_rows = "\n".join(rows)
    return f"""# {report['environment'].upper()} Detailed Inventory Accountability

This ignored runtime report lists every resource returned by discovery and the
action taken for it. It may contain resource identities and must not be
published to the destination project or committed to Git.

Reconciliation: **complete**

| Resource ARN | Service | Classification | Action | Reason | Terraform target/outcome |
| --- | --- | --- | --- | --- | --- |
{rendered_rows}
"""


def render_index(directory: Path) -> str:
    links = []
    for environment in ENVIRONMENTS:
        if (directory / f"{environment}.md").is_file():
            links.append(
                f"- [{environment.upper()} inventory](./{environment}.md)"
            )
    rendered_links = "\n".join(links) or "No environment summary is available."
    return f"""# Inventory Accountability

These reports reconcile AWS discovery with Terraform import and modularization
outcomes without publishing resource identities or private runtime data.

{rendered_links}

Detailed resource-level reports remain ignored in the `tf-importer` runtime
workspace.
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("coverage_report", type=Path)
    parser.add_argument("destination_project", type=Path)
    parser.add_argument("account_key", nargs="?", default="")
    args = parser.parse_args()

    report = json.loads(args.coverage_report.read_text(encoding="utf-8"))
    if not report["reconciliation"]["complete"]:
        raise ValueError("Refusing to publish an incomplete inventory summary")

    account_key = args.account_key or report.get("account_key", "")
    output_dir = args.destination_project / "docs" / "inventory"
    if account_key:
        output_dir /= account_key
    output_dir.mkdir(parents=True, exist_ok=True)
    environment = report["environment"]
    (output_dir / f"{environment}.md").write_text(
        render_environment(report, account_key),
        encoding="utf-8",
    )
    (output_dir / "README.md").write_text(
        render_index(output_dir),
        encoding="utf-8",
    )
    detailed_path = args.coverage_report.with_name("inventory_coverage.md")
    detailed_path.write_text(
        render_detailed_report(report),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()

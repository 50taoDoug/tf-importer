#!/usr/bin/env python3
"""Join discovery, import, and modularization outcomes into one audit report."""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def modularization_details(
    report: dict[str, Any],
) -> tuple[set[str], set[str], dict[str, str], dict[str, str]]:
    modularized: set[str] = set()
    native: set[str] = set()
    categories: dict[str, str] = {}
    native_reasons: dict[str, str] = {}
    for category in report["categories"]:
        details = category["modularization"]
        category_name = category["category"]
        for address in details["modularized"]:
            if address in categories:
                raise ValueError(
                    f"Terraform address appears in multiple categories: {address}"
                )
            modularized.add(address)
            categories[address] = category_name
        for address in details["preserved_native"]:
            if address in categories:
                raise ValueError(
                    f"Terraform address appears in multiple categories: {address}"
                )
            native.add(address)
            categories[address] = category_name
            native_reasons[address] = details.get(
                "preserved_native_reasons", {}
            ).get(address, "No reusable module contract is available.")
    return modularized, native, categories, native_reasons


def build_report(
    discovery: dict[str, Any],
    pruned: list[str],
    orphan: list[str],
    modularization: dict[str, Any],
) -> dict[str, Any]:
    for field in ("project", "environment", "region", "account_id"):
        if discovery[field] != modularization[field]:
            raise ValueError(
                f"Inventory metadata mismatch for {field}: "
                f"{discovery[field]} != {modularization[field]}"
            )

    modularized, native, categories, native_reasons = modularization_details(
        modularization
    )
    failed = set(pruned)
    orphaned = set(orphan)
    final = modularized | native

    outcome_sets = {
        "failed_remote_read": failed,
        "orphan_import": orphaned,
        "modularized": modularized,
        "native_terraform": native,
    }
    seen: set[str] = set()
    for outcome, addresses in outcome_sets.items():
        overlap = seen & addresses
        if overlap:
            raise ValueError(
                f"Import addresses have conflicting outcomes in {outcome}: "
                + ", ".join(sorted(overlap))
            )
        seen.update(addresses)

    resources = []
    generated_addresses: set[str] = set()
    discovered_arns: set[str] = set()
    service_metrics: dict[str, Counter[str]] = defaultdict(Counter)

    for item in discovery["resources"]:
        resource = dict(item)
        arn = resource["arn"]
        if arn in discovered_arns:
            raise ValueError(f"Duplicate discovered ARN: {arn}")
        discovered_arns.add(arn)
        service = resource["service"]
        classification = resource["classification"]
        declared_targets = resource.get("terraform_targets", [])
        if classification == "mapped_import_candidate" and not declared_targets:
            raise ValueError(f"Mapped resource has no import target: {arn}")
        if classification != "mapped_import_candidate" and declared_targets:
            raise ValueError(
                f"Non-mapped resource has import targets: {arn}"
            )
        service_metrics[service]["discovered"] += 1
        service_metrics[service][classification] += 1

        targets = []
        target_outcomes = []
        for target in declared_targets:
            address = target["address"]
            if address in generated_addresses:
                raise ValueError(f"Duplicate generated import address: {address}")
            generated_addresses.add(address)

            matches = [
                outcome
                for outcome, addresses in outcome_sets.items()
                if address in addresses
            ]
            if len(matches) != 1:
                raise ValueError(
                    f"Generated import address has {len(matches)} outcomes: "
                    f"{address}"
                )
            outcome = matches[0]
            target_outcomes.append(outcome)
            outcome_reasons = {
                "failed_remote_read": (
                    "Terraform reported that the remote object does not exist."
                ),
                "orphan_import": (
                    "No generated Terraform resource configuration remained "
                    "for this import."
                ),
                "modularized": "Represented by a reusable module call.",
                "native_terraform": native_reasons.get(
                    address,
                    "No reusable module contract is available.",
                ),
            }
            enriched_target = {
                **target,
                "outcome": outcome,
                "outcome_reason": outcome_reasons[outcome],
            }
            if address in categories:
                enriched_target["category"] = categories[address]
            targets.append(enriched_target)
            service_metrics[service]["generated_import_candidates"] += 1
            service_metrics[service][outcome] += 1

        resource["terraform_targets"] = targets
        if target_outcomes:
            resource["final_outcome"] = (
                target_outcomes[0]
                if len(set(target_outcomes)) == 1
                else "mixed_import_outcomes"
            )
            resource["action"] = resource["final_outcome"]
        else:
            resource["final_outcome"] = classification
            resource["action"] = {
                "excluded_by_policy": "excluded_from_terraform_generation",
                "skipped_non_importable": "skipped_as_non_importable",
                "unmapped": "left_unmapped",
                "controller_managed": "managed_by_controller",
                "represented_by_parent": "represented_by_parent",
            }[classification]
        resources.append(resource)

    missing_from_discovery = seen - generated_addresses
    unaccounted_candidates = generated_addresses - seen
    classified_resources = len(resources)
    discovered_resources = discovery["summary"]["discovered_resources"]
    complete = (
        classified_resources == discovered_resources
        and not missing_from_discovery
        and not unaccounted_candidates
    )
    if not complete:
        raise ValueError(
            "Inventory reconciliation failed: "
            f"classified={classified_resources}, discovered={discovered_resources}, "
            f"missing={sorted(missing_from_discovery)}, "
            f"unaccounted={sorted(unaccounted_candidates)}"
        )

    classification_counts = Counter(
        item["classification"] for item in resources
    )
    allowed_classifications = {
        "excluded_by_policy",
        "skipped_non_importable",
        "unmapped",
        "controller_managed",
        "represented_by_parent",
        "mapped_import_candidate",
    }
    unknown_classifications = (
        set(classification_counts) - allowed_classifications
    )
    if unknown_classifications:
        raise ValueError(
            "Unknown discovery classifications: "
            + ", ".join(sorted(unknown_classifications))
        )
    expected_discovery_summary = {
        "discovered_resources": discovered_resources,
        "classified_resources": classified_resources,
        "excluded_by_policy": classification_counts["excluded_by_policy"],
        "skipped_non_importable": classification_counts[
            "skipped_non_importable"
        ],
        "unmapped_resources": classification_counts["unmapped"],
        "controller_managed_resources": classification_counts[
            "controller_managed"
        ],
        "represented_by_parent_resources": classification_counts[
            "represented_by_parent"
        ],
        "mapped_resources": classification_counts[
            "mapped_import_candidate"
        ],
        "generated_import_candidates": len(generated_addresses),
    }
    if discovery["summary"] != expected_discovery_summary:
        raise ValueError(
            "Discovery summary does not match its resource classifications"
        )

    service_summary = []
    for service in sorted(service_metrics):
        metrics = service_metrics[service]
        service_summary.append(
            {
                "service": service,
                "discovered": metrics["discovered"],
                "excluded_by_policy": metrics["excluded_by_policy"],
                "skipped_non_importable": metrics["skipped_non_importable"],
                "unmapped": metrics["unmapped"],
                "controller_managed": metrics["controller_managed"],
                "represented_by_parent": metrics["represented_by_parent"],
                "mapped_import_candidate": metrics["mapped_import_candidate"],
                "generated_import_candidates": metrics[
                    "generated_import_candidates"
                ],
                "failed_remote_reads": metrics["failed_remote_read"],
                "orphan_imports": metrics["orphan_import"],
                "terraform_resources": (
                    metrics["modularized"] + metrics["native_terraform"]
                ),
                "modularized": metrics["modularized"],
                "native_terraform": metrics["native_terraform"],
            }
        )

    return {
        "schema_version": 1,
        "project": modularization["project"],
        "environment": modularization["environment"],
        "region": modularization["region"],
        "account_id": modularization["account_id"],
        "summary": {
            "discovered_resources": discovered_resources,
            "excluded_by_policy": classification_counts["excluded_by_policy"],
            "skipped_non_importable": classification_counts[
                "skipped_non_importable"
            ],
            "unmapped_resources": classification_counts["unmapped"],
            "controller_managed_resources": classification_counts[
                "controller_managed"
            ],
            "represented_by_parent_resources": classification_counts[
                "represented_by_parent"
            ],
            "mapped_resources": classification_counts[
                "mapped_import_candidate"
            ],
            "generated_import_candidates": len(generated_addresses),
            "failed_remote_reads": len(failed),
            "orphan_imports": len(orphaned),
            "terraform_resources": len(final),
            "modularized_resources": len(modularized),
            "native_terraform_resources": len(native),
        },
        "reconciliation": {
            "classified_resources": classified_resources,
            "accounted_import_candidates": len(seen),
            "missing_from_discovery": [],
            "unaccounted_import_candidates": [],
            "complete": True,
        },
        "service_summary": service_summary,
        "resources": sorted(resources, key=lambda item: item["arn"]),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("discovery_classification", type=Path)
    parser.add_argument("pruned_imports", type=Path)
    parser.add_argument("orphan_imports", type=Path)
    parser.add_argument("modularization_report", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    report = build_report(
        load_json(args.discovery_classification),
        load_json(args.pruned_imports),
        load_json(args.orphan_imports),
        load_json(args.modularization_report),
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()

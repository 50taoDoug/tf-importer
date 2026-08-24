#!/usr/bin/env python3
"""Build a deterministic ledger of references to other registered AWS accounts."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


ACCOUNT_ID = re.compile(r"(?<!\d)(\d{12})(?!\d)")
ARN = re.compile(
    r"arn:(?:aws|aws-us-gov|aws-cn):"
    r"(?P<service>[a-z0-9-]+):"
    r"(?P<region>[^:\s\"]*):"
    r"(?P<account_id>\d{12}):"
    r"(?P<resource>[^\"\s]+)"
)
BLOCK_START = re.compile(
    r'^\s*(?:(?P<resource>resource)\s+"(?P<type>[a-zA-Z0-9_]+)"\s+'
    r'"(?P<resource_name>[a-zA-Z0-9_]+)"|'
    r'(?P<module>module)\s+"(?P<module_name>[a-zA-Z0-9_]+)")\s*\{'
)
ATTRIBUTE = re.compile(r"^\s*(?P<name>[a-zA-Z0-9_]+)\s*=")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("terraform_root", type=Path)
    parser.add_argument("account_registry", type=Path)
    parser.add_argument("source_account_key")
    parser.add_argument("environment")
    parser.add_argument("output", type=Path)
    return parser.parse_args()


def load_registry(path: Path) -> dict[str, dict[str, str]]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()

    registry: dict[str, dict[str, str]] = {}
    indexes = sorted(
        {
            match.group(1)
            for key in values
            if (match := re.fullmatch(r"ACCOUNT_([0-9]+)_KEY", key))
        },
        key=int,
    )
    for index in indexes:
        key = values.get(f"ACCOUNT_{index}_KEY", "")
        account_id = values.get(f"ACCOUNT_{index}_ID", "")
        environments = values.get(f"ACCOUNT_{index}_ENVIRONMENTS", "")
        if not key or not re.fullmatch(r"\d{12}", account_id):
            raise ValueError(f"incomplete account registry entry ACCOUNT_{index}")
        registry[key] = {
            "account_id": account_id,
            "environments": environments,
        }
    return registry


def managed_block_lines(path: Path) -> list[tuple[str, str, str]]:
    current_address = ""
    current_type = ""
    depth = 0
    result: list[tuple[str, str, str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        start = BLOCK_START.match(line)
        if start and not current_address:
            if start.group("resource"):
                current_type = start.group("type")
                current_address = (
                    f"{current_type}.{start.group('resource_name')}"
                )
            else:
                current_type = "module"
                current_address = f"module.{start.group('module_name')}"
            depth = line.count("{") - line.count("}")
            continue
        if not current_address:
            continue
        result.append((current_address, current_type, line))
        depth += line.count("{") - line.count("}")
        if depth <= 0:
            current_address = ""
            current_type = ""
    return result


def reference_fingerprint(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def disposition(service: str) -> tuple[str, str]:
    if service in {"kms", "sqs", "dynamodb", "s3", "sns", "secretsmanager"}:
        return (
            "user_review_required",
            "Verify the owner-side resource policy; tf-importer does not change it.",
        )
    if service == "iam":
        return (
            "user_review_required",
            "Verify role trust and identity permissions; tf-importer does not change them.",
        )
    return (
        "external_reference_preserved",
        "Review the external contract; the observed literal remains unchanged.",
    )


def analyze(
    terraform_root: Path,
    registry: dict[str, dict[str, str]],
    source_key: str,
    environment: str,
) -> dict[str, Any]:
    if source_key not in registry:
        raise ValueError(f"source account is not registered: {source_key}")
    source_id = registry[source_key]["account_id"]
    owners = {
        entry["account_id"]: key
        for key, entry in registry.items()
        if key != source_key
    }

    relationships: list[dict[str, str]] = []
    observed_candidates = 0
    for path in sorted(terraform_root.rglob("*.tf")):
        relative = path.relative_to(terraform_root).as_posix()
        for address, resource_type, line in managed_block_lines(path):
            attribute_match = ATTRIBUTE.match(line)
            attribute = attribute_match.group("name") if attribute_match else ""
            arn_matches = list(ARN.finditer(line))
            arn_spans = [match.span() for match in arn_matches]

            for match in arn_matches:
                target_id = match.group("account_id")
                if target_id not in owners:
                    continue
                observed_candidates += 1
                service = match.group("service")
                outcome, user_action = disposition(service)
                value = match.group(0)
                relationships.append(
                    {
                        "source_account_key": source_key,
                        "source_account_id": source_id,
                        "target_account_key": owners[target_id],
                        "target_account_id": target_id,
                        "environment": environment,
                        "source_file": relative,
                        "source_address": address,
                        "source_type": resource_type,
                        "attribute": attribute,
                        "target_service": service,
                        "reference_kind": "arn",
                        "reference_fingerprint": reference_fingerprint(value),
                        "disposition": outcome,
                        "user_action": user_action,
                    }
                )

            for match in ACCOUNT_ID.finditer(line):
                target_id = match.group(1)
                if target_id not in owners:
                    continue
                if any(start <= match.start() < end for start, end in arn_spans):
                    continue
                observed_candidates += 1
                outcome, user_action = disposition("account")
                relationships.append(
                    {
                        "source_account_key": source_key,
                        "source_account_id": source_id,
                        "target_account_key": owners[target_id],
                        "target_account_id": target_id,
                        "environment": environment,
                        "source_file": relative,
                        "source_address": address,
                        "source_type": resource_type,
                        "attribute": attribute,
                        "target_service": "account",
                        "reference_kind": "account_id",
                        "reference_fingerprint": reference_fingerprint(target_id),
                        "disposition": outcome,
                        "user_action": user_action,
                    }
                )

    unique = {
        (
            item["source_file"],
            item["source_address"],
            item["attribute"],
            item["target_account_id"],
            item["target_service"],
            item["reference_kind"],
            item["reference_fingerprint"],
        ): item
        for item in relationships
    }
    ordered = sorted(
        unique.values(),
        key=lambda item: (
            item["target_account_key"],
            item["target_service"],
            item["source_file"],
            item["source_address"],
            item["attribute"],
            item["reference_fingerprint"],
        ),
    )
    by_service: dict[str, int] = {}
    by_target: dict[str, int] = {}
    by_disposition: dict[str, int] = {}
    for item in ordered:
        by_service[item["target_service"]] = by_service.get(item["target_service"], 0) + 1
        by_target[item["target_account_key"]] = by_target.get(item["target_account_key"], 0) + 1
        by_disposition[item["disposition"]] = (
            by_disposition.get(item["disposition"], 0) + 1
        )

    return {
        "schema_version": 1,
        "source_account_key": source_key,
        "source_account_id": source_id,
        "environment": environment,
        "summary": {
            "observed_candidates": observed_candidates,
            "unique_relationships": len(ordered),
            "duplicates_removed": observed_candidates - len(ordered),
            "by_target_account": dict(sorted(by_target.items())),
            "by_service": dict(sorted(by_service.items())),
            "by_disposition": dict(sorted(by_disposition.items())),
        },
        "reconciliation": {
            "complete": observed_candidates == len(ordered)
            + (observed_candidates - len(ordered)),
            "equation": "observed_candidates = unique_relationships + duplicates_removed",
        },
        "relationships": ordered,
    }


def main() -> int:
    args = parse_args()
    try:
        registry = load_registry(args.account_registry)
        report = analyze(
            args.terraform_root,
            registry,
            args.source_account_key,
            args.environment,
        )
    except (OSError, ValueError) as error:
        raise SystemExit(f"ERROR: {error}") from error
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

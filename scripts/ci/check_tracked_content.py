#!/usr/bin/env python3
"""Reject secrets, private paths, and runtime artifacts in tracked files."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path


ALLOWED_ACCOUNT_IDS = {"111122223333", "444455556666", "123456789012"}
ACCOUNT_ID = re.compile(r"(?<!\d)\d{12}(?!\d)")
ACCESS_KEY = re.compile(r"(?<![A-Z0-9])(?:AKIA|ASIA)[A-Z0-9]{16}(?![A-Z0-9])")
PRIVATE_KEY = re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")
SECRET_ASSIGNMENT = re.compile(
    r"(?i)(?:secret|token|password|passwd)\s*[:=]\s*[\"']?"
    r"(?!example|placeholder|redacted|<)[A-Za-z0-9/+_.=-]{16,}"
)
PRIVATE_PATH = re.compile(
    r"(?:/local-repo/|myremoterepo|[A-Za-z]:\\Users\\[^\\\s]+|/home/[^/\s]+/)"
)
FORBIDDEN_ROOTS = (
    "logs/",
    "output/",
    "reports/",
    "work/",
    "terraform/environments/",
    "tf-importer-demo-iac/",
    "examples/demo/.demo-state/",
)
FORBIDDEN_EXACT = {
    ".env",
    "accounts.json",
    "config/environments.conf",
    "config/modularization.conf",
    "config/publication-denylist.txt",
    "aws-automation-admin_accessKeys.csv",
}
FORBIDDEN_SUFFIXES = (
    ".tfstate",
    ".tfplan",
    ".bundle",
    ".pem",
    ".pfx",
    ".p12",
    ".zip",
)
PRIVATE_SOURCE_PREFIXES = (
    "docs/sprints/",
    "docs/drafts/",
    "docs/publication/",
    "scripts/publication/",
)
PRIVATE_SOURCE_PATHS = {
    "config/publication-denylist.example",
    "docs/PROJECT_CONTEXT.md",
    "docs/SESSION_HANDOFF.md",
    "docs/MODULARIZATION_ROADMAP.md",
    "docs/V2_MANIFESTO.md",
    "docs/demo/DEMO_CONTEXT.md",
    "docs/demo/RECORDING_GUIDE.md",
    "docs/demo/VIDEO_COMMANDS.md",
    "docs/demo/VIDEO_STORYBOARD.md",
}


def tracked_paths(root: Path) -> list[Path]:
    result = subprocess.run(
        [
            "git",
            "ls-files",
            "--cached",
            "--others",
            "--exclude-standard",
            "-z",
            "--",
            ".",
        ],
        cwd=root,
        check=True,
        capture_output=True,
    )
    return [
        root / item.decode("utf-8", errors="surrogateescape")
        for item in result.stdout.split(b"\0")
        if item
    ]


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    findings: list[str] = []
    paths = tracked_paths(root)

    for path in paths:
        relative = path.relative_to(root).as_posix()
        if relative in PRIVATE_SOURCE_PATHS or relative.startswith(PRIVATE_SOURCE_PREFIXES):
            continue
        lowered = relative.lower()
        if relative in FORBIDDEN_EXACT or relative.startswith(FORBIDDEN_ROOTS):
            findings.append(f"{relative}: forbidden runtime or private path")
        if lowered.endswith(FORBIDDEN_SUFFIXES) or ".tfstate." in lowered:
            findings.append(f"{relative}: forbidden artifact type")
        if not path.is_file():
            continue
        raw = path.read_bytes()
        if b"\0" in raw:
            continue
        text = raw.decode("utf-8", errors="replace")
        if ACCESS_KEY.search(text):
            findings.append(f"{relative}: possible AWS access key")
        if PRIVATE_KEY.search(text):
            findings.append(f"{relative}: possible private key")
        if SECRET_ASSIGNMENT.search(text):
            findings.append(f"{relative}: possible assigned secret or token")
        # The scanner contains the private-path signatures as source literals.
        if relative != "scripts/ci/check_tracked_content.py" and PRIVATE_PATH.search(text):
            findings.append(f"{relative}: possible private local path")
        for account_id in set(ACCOUNT_ID.findall(text)):
            if account_id not in ALLOWED_ACCOUNT_IDS:
                findings.append(f"{relative}: non-allowlisted AWS account ID")

    if findings:
        for finding in sorted(set(findings)):
            print(f"ERROR: {finding}")
        return 1

    print(f"Tracked-content audit passed: {len(paths)} paths checked.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

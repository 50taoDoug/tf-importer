#!/usr/bin/env python3
"""Validate VERSION, changelog, and an optional release tag."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
from pathlib import Path


SEMVER = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--tag",
        help="release tag to validate; defaults to the GitHub tag ref when present",
    )
    return parser.parse_args()


def git(*args: str, root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )


def main() -> int:
    args = arguments()
    root = Path(__file__).resolve().parents[2]
    version = (root / "VERSION").read_text(encoding="utf-8").strip()
    changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
    findings: list[str] = []

    if not SEMVER.fullmatch(version):
        findings.append("VERSION must contain one stable semantic version")
    if "## [Unreleased]" not in changelog:
        findings.append("CHANGELOG.md must contain an Unreleased section")
    if f"## [{version}]" not in changelog:
        findings.append(f"CHANGELOG.md has no release section for {version}")

    tag = args.tag
    if tag is None and os.environ.get("GITHUB_REF_TYPE") == "tag":
        tag = os.environ.get("GITHUB_REF_NAME")
    if tag and tag != f"v{version}":
        findings.append(f"release tag {tag!r} does not match VERSION {version!r}")

    current_tag = f"v{version}"
    tag_type = git("cat-file", "-t", current_tag, root=root)
    if tag_type.returncode == 0:
        if tag_type.stdout.strip() != "tag":
            findings.append(f"{current_tag} exists but is not an annotated tag")
        ancestor = git("merge-base", "--is-ancestor", f"{current_tag}^{{}}", "HEAD", root=root)
        if ancestor.returncode != 0:
            findings.append(f"{current_tag} is not reachable from HEAD")

    if findings:
        for finding in findings:
            print(f"ERROR: {finding}")
        return 1

    print(f"Release metadata is consistent for VERSION {version}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Reject broken relative file links in tracked Markdown documents."""

from __future__ import annotations

import re
import subprocess
import urllib.parse
from pathlib import Path


INLINE_LINK = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
REFERENCE_LINK = re.compile(r"^\s*\[[^\]]+\]:\s*(\S+)", re.MULTILINE)
REMOTE_SCHEMES = {"http", "https", "mailto"}


def tracked_markdown(root: Path) -> list[Path]:
    result = subprocess.run(
        [
            "git",
            "ls-files",
            "--cached",
            "--others",
            "--exclude-standard",
            "-z",
            "--",
            "*.md",
            "*.MD",
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


def local_target(raw: str) -> str | None:
    target = raw.strip()
    if target.startswith("<") and ">" in target:
        target = target[1 : target.index(">")]
    elif " \"" in target:
        target = target.split(" \"", 1)[0]
    parsed = urllib.parse.urlsplit(target)
    if parsed.scheme.lower() in REMOTE_SCHEMES or target.startswith("#"):
        return None
    if parsed.scheme or parsed.netloc:
        return None
    return urllib.parse.unquote(parsed.path)


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    findings: list[str] = []
    checked = 0

    for document in tracked_markdown(root):
        text = document.read_text(encoding="utf-8")
        links = INLINE_LINK.findall(text) + REFERENCE_LINK.findall(text)
        for raw in links:
            target = local_target(raw)
            if not target:
                continue
            checked += 1
            candidate = (document.parent / target).resolve()
            try:
                candidate.relative_to(root)
            except ValueError:
                findings.append(f"{document.relative_to(root)}: link escapes repository")
                continue
            if not candidate.exists():
                findings.append(
                    f"{document.relative_to(root)}: missing relative target {target}"
                )

    if findings:
        for finding in sorted(set(findings)):
            print(f"ERROR: {finding}")
        return 1

    print(f"Markdown links passed: {checked} relative targets checked.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

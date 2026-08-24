#!/usr/bin/env python3
"""Sort generated Terraform resource and import blocks deterministically."""

from __future__ import annotations

import re
import sys
from pathlib import Path


RESOURCE_START = re.compile(
    r'(?m)^resource\s+"([a-zA-Z0-9_]+)"\s+"([a-zA-Z0-9_]+)"\s*\{'
)
IMPORT_START = re.compile(r"(?m)^import\s*\{")
IMPORT_ADDRESS = re.compile(r"(?m)^[ \t]*to[ \t]*=[ \t]*([a-zA-Z0-9_.]+)")


def block_end(content: str, opening_brace: int) -> int:
    depth = 0
    in_string = False
    escaped = False

    for index in range(opening_brace, len(content)):
        character = content[index]
        if in_string:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
            continue

        if character == '"':
            in_string = True
        elif character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return index + 1

    raise ValueError("unterminated Terraform block")


def extract_blocks(content: str, pattern: re.Pattern[str]) -> list[tuple[str, str]]:
    blocks: list[tuple[str, str]] = []
    consumed_until = 0

    for match in pattern.finditer(content):
        if match.start() < consumed_until:
            continue
        if content[consumed_until:match.start()].strip():
            raise ValueError("unexpected content outside generated blocks")

        end = block_end(content, content.index("{", match.start(), match.end()))
        block = content[match.start():end].strip()
        if pattern is RESOURCE_START:
            key = f"{match.group(1)}.{match.group(2)}"
        else:
            address_match = IMPORT_ADDRESS.search(block)
            if not address_match:
                raise ValueError("import block has no destination address")
            key = address_match.group(1)
        blocks.append((key, block))
        consumed_until = end

    if content[consumed_until:].strip():
        raise ValueError("unexpected trailing content outside generated blocks")
    return blocks


def sort_file(path: Path, pattern: re.Pattern[str]) -> int:
    content = path.read_text(encoding="utf-8")
    content = re.sub(r"(?m)^[ \t]*#.*(?:\n|$)", "", content)
    blocks = extract_blocks(content, pattern)
    keys = [key for key, _ in blocks]
    if len(keys) != len(set(keys)):
        raise ValueError(f"duplicate Terraform address in {path}")

    rendered = "\n\n".join(block for _, block in sorted(blocks))
    path.write_text(f"{rendered}\n" if rendered else "", encoding="utf-8")
    return len(blocks)


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "Usage: sort_terraform_blocks.py <generated-resources.tf> <imports.tf>",
            file=sys.stderr,
        )
        return 2

    resources_path = Path(sys.argv[1])
    imports_path = Path(sys.argv[2])
    try:
        resource_count = sort_file(resources_path, RESOURCE_START)
        import_count = sort_file(imports_path, IMPORT_START)
    except (OSError, ValueError) as error:
        print(f"ERROR: deterministic Terraform sorting failed: {error}", file=sys.stderr)
        return 1

    print(
        f"Sorted {resource_count} resource blocks and "
        f"{import_count} import blocks deterministically"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

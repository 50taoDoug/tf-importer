#!/usr/bin/env bash

set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
repository_root=$(git -C "$project_root" rev-parse --show-toplevel)
project_prefix=$(git -C "$project_root" rev-parse --show-prefix)
temporary_root=$(mktemp -d "${TMPDIR:-/tmp}/tf-importer-clean.XXXXXX")

cleanup() {
    rm -rf -- "$temporary_root"
}
trap cleanup EXIT

if [[ -n "$project_prefix" ]]; then
    git -C "$repository_root" archive "HEAD:${project_prefix%/}" |
        tar -x -C "$temporary_root"
else
    git -C "$repository_root" archive HEAD | tar -x -C "$temporary_root"
fi

expected_version=$(<"$temporary_root/VERSION")
actual_version=$(
    "$temporary_root/tf-importer" version |
        awk 'NF { value=$0 } END { print value }'
)

if [[ "$actual_version" != "$expected_version" ]]; then
    printf 'ERROR: clean-checkout CLI version mismatch: expected %s, got %s\n' \
        "$expected_version" "$actual_version" >&2
    exit 1
fi

"$temporary_root/tf-importer" help >/dev/null
bash -n "$temporary_root/tf-importer"

printf 'Clean-checkout smoke test passed for tf-importer %s.\n' \
    "$expected_version"

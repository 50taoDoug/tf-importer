#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$project_root"

echo "[1/12] Running automated tests..."
make test

echo "[2/12] Checking Bash syntax..."
bash -n tf-importer
find scripts examples -type f -name '*.sh' -print0 |
    xargs -0 -r -n1 bash -n

echo "[3/12] Running ShellCheck..."
find scripts examples -type f -name '*.sh' -print0 |
    xargs -0 -r shellcheck --severity=error

echo "[4/12] Compiling Python sources..."
python3 -m compileall -q scripts tests

echo "[5/12] Validating JSON..."
json_roots=(config templates)
if [[ -d ../example-iac/config ]]; then
    json_roots+=(../example-iac/config)
fi
find "${json_roots[@]}" -type f -name '*.json' -print0 |
    xargs -0 -r -n1 jq empty

echo "[6/12] Checking Terraform formatting..."
terraform fmt -check -recursive templates/destination
if [[ -d ../example-iac ]]; then
    terraform fmt -check -recursive ../example-iac
fi

echo "[7/12] Checking offline safety boundaries..."
credential_variables=(
    AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY
    AWS_SESSION_TOKEN
    AWS_PROFILE
    AWS_WEB_IDENTITY_TOKEN_FILE
    AWS_ROLE_ARN
)
for variable_name in "${credential_variables[@]}"; do
    if [[ -n "${!variable_name:-}" ]]; then
        printf 'ERROR: make ci must run without AWS credential variable %s.\n' \
            "$variable_name" >&2
        exit 1
    fi
done

if grep -REn 'terraform[[:space:]]+apply|^apply:' \
    Makefile tf-importer scripts --include='*.sh'; then
    echo "ERROR: forbidden apply entrypoint found." >&2
    exit 1
fi

echo "[8/12] Auditing tracked content..."
python3 scripts/ci/check_tracked_content.py

echo "[9/12] Validating Markdown links..."
python3 scripts/ci/check_markdown_links.py

echo "[10/12] Validating release metadata..."
python3 scripts/ci/check_release_metadata.py

echo "[11/12] Running clean-checkout smoke test..."
bash scripts/ci/check_clean_checkout.sh

echo "[12/12] Checking Git whitespace..."
git diff --check

echo "All tf-importer CI checks passed."

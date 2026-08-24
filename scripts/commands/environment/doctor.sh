#!/usr/bin/env bash

cmd_doctor() {
    local environment="${1:-}"
    local result=0

    log_info "[1/4] Checking runtime commands..."
    doctor_check_runtime_commands || result=1

    log_info "[2/4] Checking supported versions..."
    doctor_check_runtime_versions || result=1

    log_info "[3/4] Checking AWS credentials and project configuration..."
    doctor_check_aws "$environment" || result=1

    log_info "[4/4] Checking outbound connectivity..."
    doctor_check_connectivity || result=1

    doctor_check_development_tools

    if [[ "$result" -eq 0 ]]; then
        log_success "Doctor completed: runtime environment is ready."
    else
        log_error "Doctor completed: fix the reported runtime issues before importing."
    fi
    return "$result"
}

doctor_check_runtime_commands() {
    local result=0
    local command_spec
    local runtime_commands=(
        "AWS CLI:aws"
        "Terraform:terraform"
        "jq:jq"
        "curl:curl"
        "Python 3:python3"
        "GNU awk:awk"
        "GNU sed:sed"
        "GNU grep:grep"
        "GNU find:find"
        "GNU xargs:xargs"
        "GNU mktemp:mktemp"
        "GNU realpath:realpath"
    )

    for command_spec in "${runtime_commands[@]}"; do
        check_command "${command_spec%%:*}" "${command_spec##*:}" || result=1
    done
    return "$result"
}

doctor_check_runtime_versions() {
    local result=0
    local current

    check_minimum_version "Bash" "${BASH_VERSION%%(*}" "5.0" || result=1

    if command -v terraform >/dev/null 2>&1; then
        current=$(terraform version -json 2>/dev/null |
            jq -r '.terraform_version // empty' 2>/dev/null)
        check_minimum_version "Terraform" "$current" "1.5.0" || result=1
        if [[ -n "$current" ]] && version_at_least "$current" "2.0.0"; then
            log_error "Terraform $current is unsupported (must be lower than 2.0.0)"
            result=1
        fi
    fi

    if command -v aws >/dev/null 2>&1; then
        current=$(aws --version 2>&1 | sed -nE 's#^aws-cli/([0-9.]+).*#\1#p')
        check_minimum_version "AWS CLI" "$current" "2.0.0" || result=1
    fi

    if command -v jq >/dev/null 2>&1; then
        current=$(jq --version 2>/dev/null | sed 's/^jq-//')
        check_minimum_version "jq" "$current" "1.6" || result=1
    fi

    if command -v python3 >/dev/null 2>&1; then
        current=$(python3 -c 'import platform; print(platform.python_version())' 2>/dev/null)
        check_minimum_version "Python" "$current" "3.12" || result=1
    fi

    doctor_check_gnu_utility "awk" || result=1
    doctor_check_gnu_utility "sed" || result=1
    doctor_check_gnu_utility "grep" || result=1
    doctor_check_gnu_utility "find" || result=1
    doctor_check_gnu_utility "xargs" || result=1
    doctor_check_gnu_utility "realpath" || result=1

    return "$result"
}

doctor_check_gnu_utility() {
    local command_name="$1"
    command -v "$command_name" >/dev/null 2>&1 || return 1
    if "$command_name" --version 2>&1 | head -n 1 | grep -q "GNU"; then
        log_success "$command_name is a GNU implementation"
        return 0
    fi
    log_error "$command_name must be a GNU implementation"
    return 1
}

doctor_check_aws() {
    local environment="$1"
    local account

    account=$(aws_get_account 2>/dev/null) || {
        log_error "AWS credentials are invalid, expired, or cannot reach AWS STS."
        return 1
    }
    log_success "AWS credentials valid (account $account)"

    terraform_validate_region || return 1
    if [[ -n "$environment" ]]; then
        terraform_validate_environment "$environment" || return 1
    else
        log_info "No environment supplied; account mapping was not checked."
        log_info "Use: tf-importer doctor <dev|qa|prd|demo>"
    fi
}

doctor_check_connectivity() {
    local registry_url="https://registry.terraform.io/.well-known/terraform.json"
    if curl --fail --silent --show-error --location \
        --connect-timeout 5 --max-time 15 \
        --output /dev/null "$registry_url"; then
        log_success "Terraform Registry is reachable"
        return 0
    fi

    log_error "Terraform Registry is unreachable: $registry_url"
    return 1
}

doctor_check_development_tools() {
    local result=0
    local shellcheck_version

    log_info "Optional development tools:"
    check_command "Git" git || result=1
    check_command "GNU Make" make || result=1
    if check_command "ShellCheck" shellcheck; then
        shellcheck_version=$(shellcheck --version |
            sed -nE 's/^version: ([0-9.]+)$/\1/p')
        check_minimum_version "ShellCheck" "$shellcheck_version" "0.9" || result=1
    else
        result=1
    fi

    if [[ "$result" -ne 0 ]]; then
        log_warn "Optional development checks are not fully available."
    fi
    return 0
}

#!/usr/bin/env bash

# Shared command and version checks.

check_command() {
    local name="$1"
    local cmd="$2"

    if command -v "$cmd" >/dev/null 2>&1; then
        log_success "$name found"
        return 0
    fi

    log_warn "$name not found"
    return 1
}

version_at_least() {
    local current="$1"
    local minimum="$2"
    [[ "$(printf '%s\n%s\n' "$minimum" "$current" | sort -V | head -n 1)" == "$minimum" ]]
}

check_minimum_version() {
    local name="$1"
    local current="$2"
    local minimum="$3"

    if [[ -n "$current" ]] && version_at_least "$current" "$minimum"; then
        log_success "$name $current (minimum $minimum)"
        return 0
    fi

    log_error "$name ${current:-unknown} is unsupported (minimum $minimum)"
    return 1
}

#!/usr/bin/env bash

dispatch() {
  local cmd="${1:-}"
  shift || true

  log_debug "dispatch cmd=$cmd args=$*"

  local fn="${REGISTERED_COMMANDS[$cmd]:-}"

  # 1. Unknown command
  if [[ -z "$fn" ]]; then
    log_error "Unknown command: $cmd"
    echo "Unknown command: $cmd"
    return 2
  fi

  # 2. Missing handler function (internal bug)
  if ! declare -F "$fn" >/dev/null 2>&1; then
    log_error "Function not found: $fn"
    echo "Internal error: command handler missing ($fn)"
    return 3
  fi

  # 3. Execute command
  "$fn" "$@"
}

#!/usr/bin/env bash

load_command() {
  local path="$1"
  local file="${PROJECT_ROOT}/scripts/commands/${path}.sh"

  if [[ ! -f "$file" ]]; then
    log_error "missing command file: $file"
    return 1
  fi

  source "$file"

  local cmd_name
  cmd_name="$(basename "$path")"

  local fn="cmd_${cmd_name}"

  if ! declare -F "$fn" >/dev/null 2>&1; then
    log_error "command function not found: $fn"
    return 1
  fi

  REGISTERED_COMMANDS["$cmd_name"]="$fn"

  log_debug "command loaded: ${path} -> ${fn}"
}

#!/usr/bin/env bash

LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-${PROJECT_ROOT:-.}/logs/tf-importer.log}"
LOG_CONSOLE="${LOG_CONSOLE:-1}"

mkdir -p "$(dirname "$LOG_FILE")"

_timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

_level_value() {
  case "$1" in
    DEBUG) echo 0 ;;
    INFO) echo 1 ;;
    WARN) echo 2 ;;
    ERROR) echo 3 ;;
    SUCCESS) echo 1 ;;
    *) echo 1 ;;
  esac
}

_should_log() {
  [[ $(_level_value "$1") -ge $(_level_value "$LOG_LEVEL") ]]
}

_log() {
  local level="$1"
  shift
  local message="$*"

  _should_log "$level" || return 0

  local line
  line="$(_timestamp) [$level] $message"
  printf '%s\n' "$line" >> "$LOG_FILE"

  if [[ "$LOG_CONSOLE" != "0" ]]; then
    printf '%s\n' "$line" >&2
  fi
}

log_info()    { _log INFO "$*"; }
log_warn()    { _log WARN "$*"; }
log_error()   { _log ERROR "$*"; }
log_debug()   { _log DEBUG "$*"; }
log_success() { _log SUCCESS "$*"; }

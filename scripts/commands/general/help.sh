#!/usr/bin/env bash

cmd_help() {
  echo "tf-importer"
  echo ""
  echo "Commands:"
  for k in "${!REGISTERED_COMMANDS[@]}"; do
    echo "  $k"
  done | sort
}

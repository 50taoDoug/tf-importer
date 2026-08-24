#!/usr/bin/env bash

# =====================================================
# tf-importer - validate command
# =====================================================

cmd_validate() {
    log_info "The validate command uses the complete doctor validation."
    cmd_doctor "${1:-}"
}

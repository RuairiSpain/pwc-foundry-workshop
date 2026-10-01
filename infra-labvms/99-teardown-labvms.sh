#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/00-labvm-config.sh"
preflight
warn "This deletes resource group '$LAB_RG' and every lab VM in it."
read -r -p "Type the resource group name to confirm: " c
[[ "$c" == "$LAB_RG" ]] || die "mismatch, aborting"
az group delete -n "$LAB_RG" --yes --no-wait
rm -f "$LAB_OUT/labvm-credentials.csv"
log "Teardown started. Credentials file removed."

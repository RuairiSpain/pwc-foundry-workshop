#!/usr/bin/env bash
# Manual start of the AUTO attendee VMs (tag schedule=auto).
# Normally the 08:30 schedule does this - use it as a manual override.
# Reserve VMs and your test VM are NOT touched:
#   ./start-reserve-vms.sh 26 27
#   ./test-vm.sh start
source "$(dirname "${BASH_SOURCE[0]}")/00-labvm-config.sh"
preflight
IDS=$(az vm list -g "$LAB_RG" --query "[?tags.schedule=='auto'].id" -o tsv)
[[ -n "$IDS" ]] || die "no VMs tagged schedule=auto in $LAB_RG"
log "Starting $(echo "$IDS" | wc -l) auto-scheduled attendee VMs"
az vm start --ids $IDS --no-wait
log "Started. Allow ~5 minutes before they are reachable."

#!/usr/bin/env bash
# Manual deallocate of the AUTO attendee VMs (tag schedule=auto).
# The 14:00 schedule does this automatically - run it earlier if class ends early.
# Reserve VMs and your test VM are NOT touched:
#   ./stop-reserve-vms.sh 26 27
#   ./test-vm.sh stop
source "$(dirname "${BASH_SOURCE[0]}")/00-labvm-config.sh"
preflight
IDS=$(az vm list -g "$LAB_RG" --query "[?tags.schedule=='auto'].id" -o tsv)
[[ -n "$IDS" ]] || die "no VMs tagged schedule=auto in $LAB_RG"
log "Deallocating $(echo "$IDS" | wc -l) auto-scheduled attendee VMs"
az vm deallocate --ids $IDS --no-wait
log "Deallocating. Compute billing stops at state 'Deallocated'."

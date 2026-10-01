#!/usr/bin/env bash
# YOUR test VM. Never touched by any schedule.
#   ./test-vm.sh start | stop | status | cost
source "$(dirname "${BASH_SOURCE[0]}")/00-labvm-config.sh"
preflight
VM="$LAB_TEST_VM"

case "${1:-status}" in
  start)
    log "Starting $VM"
    az vm start -g "$LAB_RG" -n "$VM" --output none
    log "Running. Connect: portal -> $VM -> Connect -> Bastion"
    log "  Windows sign-in : $LAB_ADMIN / $LAB_PASSWORD"
    log "  Then inside the VM, test STUDENT permissions with:"
    log "    az login --use-device-code   (sign in as ${LAB_TEST_IDENTITY}@${WS_TENANT_DOMAIN})"
    ;;
  stop)
    log "Deallocating $VM"
    az vm deallocate -g "$LAB_RG" -n "$VM" --output none
    log "Deallocated. No compute charge."
    ;;
  status)
    az vm show -g "$LAB_RG" -n "$VM" -d \
      --query "{name:name, power:powerState, size:hardwareProfile.vmSize, schedule:tags.schedule}" -o table
    ;;
  cost)
    echo "Test VM size: ${LAB_TEST_VM_SIZE}"
    echo "B4ms test VM at ~\$0.33/hr:  1 day ~\$8  |  1 week left running ~\$55"
    echo "Deallocate it when you are not testing."
    ;;
  *) die "usage: ./test-vm.sh start|stop|status|cost" ;;
esac

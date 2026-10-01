#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# BELT AND BRACES: a daily auto-shutdown on every lab VM.
#
# Attendees already CANNOT start or stop VMs (they hold Reader only), so this
# is not about them - it is about YOU forgetting to run ./stop-vms.sh.
# A forgotten weekend of 30 running VMs costs roughly $475.
#
# Azure auto-shutdown is FREE. There is no reason not to set it.
#
# NOTE ON TIME: az vm auto-shutdown takes UTC unless a timezone is set.
# This script sets the timezone explicitly so you can pass local time.
#   ./40-auto-shutdown.sh          -> 14:00 Madrid time
#   ./40-auto-shutdown.sh 1500     -> 15:00 Madrid time
#
# Your test VM (tag schedule=manual) is SKIPPED - you control that one.
# ---------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/00-labvm-config.sh"
preflight

SHUTDOWN_TIME="${1:-1400}"   # 14:00, matching the lab finish
TZID="${LAB_TIMEZONE:-Romance Standard Time}"   # Madrid / Paris / Brussels

log "Setting auto-shutdown at ${SHUTDOWN_TIME} (${TZID}) on $LAB_COUNT VMs"

for i in $(seq -w 1 "$LAB_COUNT"); do
  VM="${LAB_PREFIX}-${i}"
  # never schedule the instructor test VM
  [[ "$VM" == "$LAB_TEST_VM" ]] && continue
  VM_ID=$(az vm show -g "$LAB_RG" -n "$VM" --query id -o tsv 2>/dev/null) || {
    warn "  $VM not found"; continue; }

  (
    az resource create -g "$LAB_RG" \
      --resource-type "Microsoft.DevTestLab/schedules" \
      -n "shutdown-computevm-${VM}" \
      --location "$LAB_LOCATION" \
      --properties "{
        \"status\": \"Enabled\",
        \"taskType\": \"ComputeVmShutdownTask\",
        \"dailyRecurrence\": {\"time\": \"${SHUTDOWN_TIME}\"},
        \"timeZoneId\": \"${TZID}\",
        \"targetResourceId\": \"${VM_ID}\",
        \"notificationSettings\": {\"status\": \"Disabled\", \"timeInMinutes\": 30}
      }" --output none 2>/dev/null && log "  OK   $VM" || warn "  FAIL $VM"
  ) &
  while [[ $(jobs -rp | wc -l) -ge 8 ]]; do sleep 1; done
done
wait

log "Auto-shutdown set. VMs now stop themselves at ${SHUTDOWN_TIME} ${TZID} daily."
warn "This is a DAILY backstop that fires even on non-training days - harmless."
warn "Your test VM $LAB_TEST_VM is excluded. Stop it with ./test-vm.sh stop."

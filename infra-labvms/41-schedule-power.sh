#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# AUTOMATED START 08:30 / STOP 14:00 on the training days only.
#
# Creates an Azure Automation account with a managed identity, a tag-driven
# runbook, and one-time schedules for each training day.
#
# Only VMs tagged schedule=auto are affected. Reserve VMs (schedule=reserve)
# and your test VM (schedule=manual) are never touched.
#
#   ./41-schedule-power.sh            create the real schedules
#   ./41-schedule-power.sh --test     ALSO add a start 10 minutes from now,
#                                     so you can prove it works TODAY
#   ./41-schedule-power.sh --list     show what is scheduled
# ---------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/00-labvm-config.sh"
preflight

API="2023-11-01"
BASE="https://management.azure.com/subscriptions/${WS_SUBSCRIPTION_ID}/resourceGroups/${LAB_RG}/providers/Microsoft.Automation/automationAccounts/${LAB_AUTOMATION}"
RUNBOOK="Set-LabVmPower"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--list" ]]; then
  log "Scheduled jobs:"
  az rest --method get --url "${BASE}/schedules?api-version=${API}" \
    --query "value[].{name:name, start:properties.startTime, tz:properties.timeZone, expired:properties.isEnabled}" \
    -o table 2>/dev/null || die "Automation account not found - run without --list first"
  exit 0
fi

# 1. Automation account with a system-assigned managed identity -------------
log "Creating Automation account $LAB_AUTOMATION"
az rest --method put --url "${BASE}?api-version=${API}" --body "{
  \"location\": \"${LAB_LOCATION}\",
  \"identity\": {\"type\": \"SystemAssigned\"},
  \"properties\": {\"sku\": {\"name\": \"Free\"}}
}" --output none 2>/dev/null || warn "account may already exist - continuing"

log "Waiting for the managed identity to appear"
for _ in $(seq 1 20); do
  MI=$(az rest --method get --url "${BASE}?api-version=${API}" --query "identity.principalId" -o tsv 2>/dev/null || true)
  [[ -n "$MI" && "$MI" != "null" ]] && break
  sleep 5
done
[[ -n "$MI" && "$MI" != "null" ]] || die "managed identity never appeared"
log "Managed identity: $MI"

# 2. Let it power-manage the lab resource group ONLY ------------------------
ROLE_VM_CONTRIBUTOR="9980e02c-c2be-4d73-94e8-173b1dc7cf3c"
LAB_RG_SCOPE="/subscriptions/${WS_SUBSCRIPTION_ID}/resourceGroups/${LAB_RG}"
az role assignment create --assignee-object-id "$MI" --assignee-principal-type ServicePrincipal \
  --role "$ROLE_VM_CONTRIBUTOR" --scope "$LAB_RG_SCOPE" --output none 2>/dev/null \
  || warn "role assignment already present or failed"
log "Granted Virtual Machine Contributor on $LAB_RG (that group only)"

# 3. Runbook ---------------------------------------------------------------
log "Creating runbook $RUNBOOK"
az rest --method put --url "${BASE}/runbooks/${RUNBOOK}?api-version=${API}" --body "{
  \"location\": \"${LAB_LOCATION}\",
  \"properties\": {
    \"runbookType\": \"PowerShell72\",
    \"logProgress\": true,
    \"logVerbose\": false,
    \"description\": \"Start/stop lab VMs by tag\",
    \"draft\": {}
  }
}" --output none 2>/dev/null || warn "runbook may already exist"

log "Uploading runbook content"
az rest --method put --url "${BASE}/runbooks/${RUNBOOK}/draft/content?api-version=${API}" \
  --headers "Content-Type=text/powershell" \
  --body "@${HERE}/runbook-labvm-power.ps1" --output none \
  || die "runbook content upload failed"

log "Publishing runbook"
az rest --method post --url "${BASE}/runbooks/${RUNBOOK}/publish?api-version=${API}" --output none \
  || warn "publish returned non-zero (often still succeeds) - check the portal"

# 4. Schedules -------------------------------------------------------------
make_schedule () {   # make_schedule <name> <iso-datetime> <Start|Stop>
  local NAME="$1" WHEN="$2" ACTION="$3"
  az rest --method put --url "${BASE}/schedules/${NAME}?api-version=${API}" --body "{
    \"name\": \"${NAME}\",
    \"properties\": {
      \"description\": \"${ACTION} lab VMs\",
      \"startTime\": \"${WHEN}\",
      \"frequency\": \"OneTime\",
      \"timeZone\": \"${LAB_TIMEZONE}\"
    }
  }" --output none 2>/dev/null || { warn "  schedule ${NAME} failed (past date?)"; return 1; }

  local GUID; GUID=$(cat /proc/sys/kernel/random/uuid)
  az rest --method put --url "${BASE}/jobSchedules/${GUID}?api-version=${API}" --body "{
    \"properties\": {
      \"schedule\": {\"name\": \"${NAME}\"},
      \"runbook\":  {\"name\": \"${RUNBOOK}\"},
      \"parameters\": {
        \"Action\": \"${ACTION}\",
        \"ResourceGroupName\": \"${LAB_RG}\",
        \"TagName\": \"schedule\",
        \"TagValue\": \"auto\"
      }
    }
  }" --output none 2>/dev/null && log "  OK  ${NAME}  ${WHEN}" \
    || warn "  link failed for ${NAME}"
}

log "Creating schedules for: $LAB_DAYS"
log "Schedules will affect only the first $LAB_AUTO_COUNT attendee VMs tagged schedule=auto."
log "Reserve VMs start manually with: ./start-reserve-vms.sh $(printf '%02d' $((LAB_AUTO_COUNT + 1)))"
for DAY in $LAB_DAYS; do
  SHORT="${DAY//-/}"
  make_schedule "start-${SHORT}" "${DAY}T${LAB_START_TIME}:00${LAB_TZ_OFFSET}" "Start" || true
  make_schedule "stop-${SHORT}"  "${DAY}T${LAB_STOP_TIME}:00${LAB_TZ_OFFSET}"  "Stop"  || true
done

# 5. Optional proof-it-works run -------------------------------------------
if [[ "${1:-}" == "--test" ]]; then
  TEST_AT=$(date -u -d "+12 minutes" +"%Y-%m-%dT%H:%M:00+00:00")
  log "TEST: scheduling a Start 12 minutes from now ($TEST_AT UTC)"
  make_schedule "test-start-$(date +%H%M)" "$TEST_AT" "Start" || true
  warn "Watch it fire:  Automation account -> Jobs. Then run ./stop-vms.sh"
fi

echo
log "Done. Verify with:  ./41-schedule-power.sh --list"
warn "IMPORTANT: run this at least once with --test today. Automation schedules"
warn "that have never fired are the classic thing that silently does not work."

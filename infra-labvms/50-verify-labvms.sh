#!/usr/bin/env bash
# Confirms attendees can CONNECT but cannot START, STOP or DELETE VMs,
# and that the auto-shutdown backstop is in place.
source "$(dirname "${BASH_SOURCE[0]}")/00-labvm-config.sh"
preflight

PASS=0; FAIL=0
ok()  { printf '  \033[1;32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[1;31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

log "1. VM inventory and power state"
az vm list -g "$LAB_RG" -d --query "[].{name:name, state:powerState, size:hardwareProfile.vmSize}" -o table 2>/dev/null
N=$(az vm list -g "$LAB_RG" --query "length(@)" -o tsv 2>/dev/null || echo 0)
EXPECTED=$((LAB_COUNT + 1))
[[ "$N" == "$EXPECTED" ]] && ok "$N VMs present ($LAB_COUNT attendees + test VM)" || bad "found $N VMs, expected $EXPECTED"

AUTO=$(az vm list -g "$LAB_RG" --query "length([?tags.schedule=='auto'])" -o tsv 2>/dev/null || echo 0)
RESERVE=$(az vm list -g "$LAB_RG" --query "length([?tags.schedule=='reserve'])" -o tsv 2>/dev/null || echo 0)
MANUAL=$(az vm list -g "$LAB_RG" --query "length([?tags.schedule=='manual'])" -o tsv 2>/dev/null || echo 0)
EXPECTED_RESERVE=$((LAB_COUNT - LAB_AUTO_COUNT))
[[ "$AUTO" == "$LAB_AUTO_COUNT" ]] && ok "$AUTO auto-scheduled VMs" || bad "$AUTO auto-scheduled VMs, expected $LAB_AUTO_COUNT"
[[ "$RESERVE" == "$EXPECTED_RESERVE" ]] && ok "$RESERVE reserve VMs" || bad "$RESERVE reserve VMs, expected $EXPECTED_RESERVE"
[[ "$MANUAL" == "1" ]] && ok "1 manual instructor test VM" || bad "$MANUAL manual VMs, expected 1"

RUNNING=$(az vm list -g "$LAB_RG" -d --query "length([?powerState=='VM running'])" -o tsv 2>/dev/null || echo 0)
log "   Currently running: $RUNNING  (should be 0 outside session hours)"

log "2. Attendees must NOT hold power permissions (sampling)"
for i in 01 $(printf '%02d' $((LAB_COUNT/2))) $(printf '%02d' "$LAB_COUNT"); do
  UPN="attendee${i}@${WS_TENANT_DOMAIN}"
  VM="${LAB_PREFIX}-${i}"
  OID=$(az ad user show --id "$UPN" --query id -o tsv 2>/dev/null || true)
  VM_ID=$(az vm show -g "$LAB_RG" -n "$VM" --query id -o tsv 2>/dev/null || true)
  [[ -n "$OID" && -n "$VM_ID" ]] || { bad "cannot resolve $UPN / $VM"; continue; }

  # Any role other than Reader at VM scope is a red flag.
  ROLES=$(az role assignment list --assignee "$OID" --scope "$VM_ID" --include-inherited \
          --query "[].roleDefinitionName" -o tsv 2>/dev/null | sort -u | tr '\n' ' ')
  if [[ "$ROLES" == *"Contributor"* || "$ROLES" == *"Virtual Machine Contributor"* || "$ROLES" == *"Owner"* ]]; then
    bad "$UPN has POWER rights on $VM (roles: $ROLES)"
  else
    ok "$UPN: read-only on $VM (roles: ${ROLES:-none})"
  fi

  # They must not see a neighbour's VM either.
  OTHER="${LAB_PREFIX}-02"
  if [[ "$i" != "02" ]]; then
    OID2=$(az vm show -g "$LAB_RG" -n "$OTHER" --query id -o tsv 2>/dev/null || true)
    L=$(az role assignment list --assignee "$OID" --scope "$OID2" \
        --query "[?scope=='$OID2'] | length(@)" -o tsv 2>/dev/null || echo 0)
    [[ "$L" -eq 0 ]] && ok "$UPN cannot see $OTHER" || bad "$UPN LEAKS into $OTHER"
  fi
done

log "3. Auto-shutdown backstop"
S=$(az resource list -g "$LAB_RG" --resource-type "Microsoft.DevTestLab/schedules" \
    --query "length(@)" -o tsv 2>/dev/null || echo 0)
[[ "$S" -ge "$LAB_COUNT" ]] && ok "$S auto-shutdown schedules" \
  || bad "only $S schedules for $LAB_COUNT VMs - run ./40-auto-shutdown.sh"

echo
log "RESULT: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || die "Fix the failures above."

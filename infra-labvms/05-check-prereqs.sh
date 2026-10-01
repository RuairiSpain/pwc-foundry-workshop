#!/usr/bin/env bash
# Read-only checks for the Bastion + VM lab environment.
source "$(dirname "${BASH_SOURCE[0]}")/00-labvm-config.sh"
preflight

PASS=0; FAIL=0
ok()  { printf '\033[1;32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '\033[1;31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

provider_state() {
  az provider show -n "$1" --query registrationState -o tsv 2>/dev/null || echo "NotRegistered"
}

log "1. Required resource providers"
for ns in Microsoft.Compute Microsoft.Network Microsoft.DevTestLab Microsoft.Automation; do
  STATE=$(provider_state "$ns")
  [[ "$STATE" == "Registered" ]] && ok "$ns registered" || bad "$ns is $STATE - run: az provider register -n $ns --wait"
done

log "2. VM quota in $LAB_LOCATION"
ATTENDEE_VCPUS=$((LAB_COUNT * 2))
TEST_VCPUS=4
REQUIRED=$((ATTENDEE_VCPUS + TEST_VCPUS))
REGIONAL_LIMIT=$(az vm list-usage -l "$LAB_LOCATION" \
  --query "[?localName=='Total Regional vCPUs'].limit | [0]" -o tsv 2>/dev/null || echo 0)
BS_LIMIT=$(az vm list-usage -l "$LAB_LOCATION" \
  --query "[?localName=='Standard BS Family vCPUs'].limit | [0]" -o tsv 2>/dev/null || echo 0)

[[ "$REGIONAL_LIMIT" -ge "$REQUIRED" ]] && ok "regional vCPU quota $REGIONAL_LIMIT >= required $REQUIRED" \
  || bad "regional vCPU quota $REGIONAL_LIMIT < required $REQUIRED"
[[ "$BS_LIMIT" -ge "$REQUIRED" ]] && ok "BS-family vCPU quota $BS_LIMIT >= required $REQUIRED" \
  || bad "BS-family vCPU quota $BS_LIMIT < required $REQUIRED"

log "3. Planned VM split"
RESERVE=$((LAB_COUNT - LAB_AUTO_COUNT))
ok "$LAB_COUNT attendee VMs: $LAB_AUTO_COUNT auto + $RESERVE reserve"
ok "test VM is manual only: $LAB_TEST_VM ($LAB_TEST_VM_SIZE)"

echo
log "RESULT: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || die "Fix the failures above before creating lab VMs."

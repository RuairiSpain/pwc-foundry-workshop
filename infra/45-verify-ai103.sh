#!/usr/bin/env bash
# Read-only checks that the AI-103 sandboxes will actually work.
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"
preflight
: "${WS_AI103_RG_PREFIX:=rg-pwc-ai103}"
ROLE_OWNER="8e3af657-a8ff-443c-a75c-2fe8c4bcb635"

PASS=0; FAIL=0
ok()   { printf '  \033[1;32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[1;31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

log "1. Sandbox resource groups (expecting $WS_ATTENDEE_COUNT)"
N=$(az group list --query "length([?starts_with(name,'${WS_AI103_RG_PREFIX}')])" -o tsv 2>/dev/null || echo 0)
[[ "$N" == "$WS_ATTENDEE_COUNT" ]] && ok "$N sandbox groups" || bad "found $N, expected $WS_ATTENDEE_COUNT"

log "2. Owner on own sandbox, and NOT on a neighbour's (sampling)"
for i in 01 $(printf '%02d' $((WS_ATTENDEE_COUNT/2))) $(printf '%02d' "$WS_ATTENDEE_COUNT"); do
  upn="${WS_ATTENDEE_PREFIX}${i}@${WS_TENANT_DOMAIN}"
  OID=$(az ad user show --id "$upn" --query id -o tsv 2>/dev/null || true)
  [[ -n "$OID" ]] || { bad "no user $upn"; continue; }
  MINE="/subscriptions/${WS_SUBSCRIPTION_ID}/resourceGroups/${WS_AI103_RG_PREFIX}-${i}"
  M=$(az role assignment list --assignee "$OID" --scope "$MINE" \
      --query "[?contains(roleDefinitionId,'$ROLE_OWNER')] | length(@)" -o tsv 2>/dev/null || echo 0)
  [[ "$M" -ge 1 ]] && ok "$upn owns their sandbox" || bad "$upn has NO Owner on $MINE"

  OTHER="/subscriptions/${WS_SUBSCRIPTION_ID}/resourceGroups/${WS_AI103_RG_PREFIX}-02"
  if [[ "$i" != "02" ]]; then
    L=$(az role assignment list --assignee "$OID" --scope "$OTHER" \
        --query "[?scope=='$OTHER'] | length(@)" -o tsv 2>/dev/null || echo 0)
    [[ "$L" -eq 0 ]] && ok "$upn has no rights on sandbox 02" || bad "$upn LEAKS into sandbox 02"
  fi
done

log "3. Subscription-level quota headroom (the real constraint)"
warn "   Each attendee deploys their OWN models. Check per-model quota:"
az cognitiveservices usage list -l "$WS_LOCATION" \
  --query "[?contains(name.value,'OpenAI')].{name:name.localizedValue, used:currentValue, limit:limit}" \
  -o table 2>/dev/null | head -20 || warn "   could not read usage"
echo
warn "   Rule of thumb: $WS_ATTENDEE_COUNT attendees x their deployment capacity"
warn "   must fit under the subscription limit shown above."

echo
log "RESULT: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || die "Fix the failures above."

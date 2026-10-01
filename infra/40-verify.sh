#!/usr/bin/env bash
# Read-only verification. Run this the day before AND the morning of.
# Exits non-zero if anything that would break the workshop is wrong.
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"
preflight

PASS=0; FAIL=0
check () { # check <label> <command...>
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then printf '  \033[1;32mPASS\033[0m %s\n' "$label"; PASS=$((PASS+1));
  else printf '  \033[1;31mFAIL\033[0m %s\n' "$label"; FAIL=$((FAIL+1)); fi
}

log "1. Subscription and identity"
check "signed in"                 az account show
check "subscription reachable"    az account show --subscription "$WS_SUBSCRIPTION_ID"

log "2. Foundry hub"
check "resource group exists"     az group show -n "$WS_RESOURCE_GROUP"
check "hub account exists"        az cognitiveservices account show -g "$WS_RESOURCE_GROUP" -n "$WS_FOUNDRY_ACCOUNT"

KIND=$(az cognitiveservices account show -g "$WS_RESOURCE_GROUP" -n "$WS_FOUNDRY_ACCOUNT" --query kind -o tsv 2>/dev/null || echo none)
if [[ "$KIND" == "AIServices" ]]; then printf '  \033[1;32mPASS\033[0m hub kind is AIServices\n'; PASS=$((PASS+1))
else printf '  \033[1;31mFAIL\033[0m hub kind is "%s" - must be AIServices\n' "$KIND"; FAIL=$((FAIL+1)); fi

log "3. Model deployments"
for m in "$WS_CHAT_MODEL" "$WS_CHAT_MODEL_B" "$WS_ROUTER_MODEL" "$WS_EMBEDDING_MODEL"; do
  check "deployment $m" az cognitiveservices account deployment show \
    -g "$WS_RESOURCE_GROUP" -n "$WS_FOUNDRY_ACCOUNT" --deployment-name "$m"
done
log "   capacity (TPM) per deployment:"
az cognitiveservices account deployment list -g "$WS_RESOURCE_GROUP" -n "$WS_FOUNDRY_ACCOUNT" \
  --query "[].{name:name, capacity:sku.capacity}" -o table 2>/dev/null || warn "   could not list"

log "4. Spoke projects (expecting $WS_ATTENDEE_COUNT)"
FOUND=$(az cognitiveservices account project list -g "$WS_RESOURCE_GROUP" \
  --name "$WS_FOUNDRY_ACCOUNT" --query "length([?starts_with(name,'$WS_PROJECT_PREFIX')])" -o tsv 2>/dev/null || echo 0)
if [[ "$FOUND" == "$WS_ATTENDEE_COUNT" ]]; then printf '  \033[1;32mPASS\033[0m %s projects\n' "$FOUND"; PASS=$((PASS+1))
else printf '  \033[1;31mFAIL\033[0m found %s projects, expected %s\n' "$FOUND" "$WS_ATTENDEE_COUNT"; FAIL=$((FAIL+1)); fi

log "5. Attendee identities and per-capability permissions (sampling)"
SAMPLE="01 $(printf '%02d' $((WS_ATTENDEE_COUNT/2))) $(printf '%02d' "$WS_ATTENDEE_COUNT")"
for i in $SAMPLE; do
  upn="${WS_ATTENDEE_PREFIX}${i}@${WS_TENANT_DOMAIN}"
  proj="${WS_PROJECT_PREFIX}-${i}"
  check "user $upn" az ad user show --id "$upn"
  OID=$(az ad user show --id "$upn" --query id -o tsv 2>/dev/null || true)
  [[ -n "$OID" ]] || continue

  has_role () {  # has_role <roleId> <scope> <label>
    N=$(az role assignment list --assignee "$OID" --scope "$2" --include-inherited \
        --query "[?roleDefinitionId!=null && contains(roleDefinitionId, '$1')] | length(@)" -o tsv 2>/dev/null || echo 0)
    if [[ "$N" -ge 1 ]]; then printf '  \033[1;32mPASS\033[0m %s: %s\n' "$upn" "$3"; PASS=$((PASS+1));
    else printf '  \033[1;31mFAIL\033[0m %s: MISSING %s\n' "$upn" "$3"; FAIL=$((FAIL+1)); fi
  }

  has_role "$ROLE_READER"                  "$WS_ACCOUNT_SCOPE"                  "see hub + shared models"
  has_role "$ROLE_FOUNDRY_PROJECT_MANAGER" "$WS_ACCOUNT_SCOPE/projects/$proj"   "create agents + connections on own spoke"
  has_role "$ROLE_OPENAI_USER"             "$WS_ACCOUNT_SCOPE"                  "memory store embeddings"
  has_role "$ROLE_ACR_PUSH"                "$WS_RG_SCOPE"                       "push agent images"
  has_role "$ROLE_MONITORING_READER"       "$WS_APPI_SCOPE"                     "read traces (Lab 5)"
  has_role "$ROLE_LOG_ANALYTICS_READER"    "$WS_LAW_SCOPE"                      "run KQL (Lab 5)"
done

log "5b. Project managed identities (sampling)"
for i in $SAMPLE; do
  proj="${WS_PROJECT_PREFIX}-${i}"
  MI=$(az cognitiveservices account project show -g "$WS_RESOURCE_GROUP" \
        --name "$WS_FOUNDRY_ACCOUNT" --project-name "$proj" \
        --query identity.principalId -o tsv 2>/dev/null || true)
  if [[ -z "$MI" || "$MI" == "null" ]]; then
    printf '  \033[1;31mFAIL\033[0m %s has no managed identity\n' "$proj"; FAIL=$((FAIL+1)); continue
  fi
  N=$(az role assignment list --assignee "$MI" --scope "$WS_ACCOUNT_SCOPE" \
      --query "length(@)" -o tsv 2>/dev/null || echo 0)
  if [[ "$N" -ge 1 ]]; then printf '  \033[1;32mPASS\033[0m %s identity can reach the hub\n' "$proj"; PASS=$((PASS+1));
  else printf '  \033[1;31mFAIL\033[0m %s identity has no hub access - agents will fail at runtime\n' "$proj"; FAIL=$((FAIL+1)); fi
done

log "6. Observability"
check "log analytics workspace"  az monitor log-analytics workspace show -g "$WS_RESOURCE_GROUP" -n "$WS_LAW"
check "application insights"     az monitor app-insights component show --app "$WS_APPINSIGHTS" -g "$WS_RESOURCE_GROUP"
check "diagnostic setting"       az monitor diagnostic-settings show --name foundry-to-law --resource "$WS_ACCOUNT_SCOPE"

log "7. Isolation check - attendee01 must have NO data rights on spoke 02"
OID1=$(az ad user show --id "${WS_ATTENDEE_PREFIX}01@${WS_TENANT_DOMAIN}" --query id -o tsv 2>/dev/null || true)
if [[ -n "$OID1" ]]; then
  LEAK=0
  for RID in "$ROLE_FOUNDRY_USER" "$ROLE_FOUNDRY_PROJECT_MANAGER"; do
    N=$(az role assignment list --assignee "$OID1" \
      --scope "$WS_ACCOUNT_SCOPE/projects/${WS_PROJECT_PREFIX}-02" \
      --query "[?contains(roleDefinitionId, '$RID')] | length(@)" -o tsv 2>/dev/null || echo 0)
    LEAK=$((LEAK + N))
  done
  # A data-plane role at HUB scope would inherit to every spoke - also a leak.
  for RID in "$ROLE_FOUNDRY_USER" "$ROLE_FOUNDRY_PROJECT_MANAGER"; do
    N=$(az role assignment list --assignee "$OID1" --scope "$WS_ACCOUNT_SCOPE" \
      --query "[?contains(roleDefinitionId, '$RID') && scope=='$WS_ACCOUNT_SCOPE'] | length(@)" -o tsv 2>/dev/null || echo 0)
    LEAK=$((LEAK + N))
  done
  if [[ "$LEAK" -eq 0 ]]; then printf '  \033[1;32mPASS\033[0m no cross-spoke data access\n'; PASS=$((PASS+1))
  else printf '  \033[1;31mFAIL\033[0m attendee01 has %s data-plane grant(s) beyond their own spoke\n' "$LEAK"; FAIL=$((FAIL+1)); fi
fi

echo
log "RESULT: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || die "Fix the failures above before the workshop."
log "Environment looks ready."

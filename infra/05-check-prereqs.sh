#!/usr/bin/env bash
# Read-only checks to run before creating users or resources.
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"
preflight

PASS=0; FAIL=0
ok()  { printf '\033[1;32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '\033[1;31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

provider_state() {
  az provider show -n "$1" --query registrationState -o tsv 2>/dev/null || echo "NotRegistered"
}

log "1. Azure subscription context"
ACCOUNT_SUB=$(az account show --query id -o tsv 2>/dev/null || true)
ACCOUNT_TENANT=$(az account show --query tenantId -o tsv 2>/dev/null || true)
[[ "$ACCOUNT_SUB" == "$WS_SUBSCRIPTION_ID" ]] && ok "subscription selected: $WS_SUBSCRIPTION_ID" || bad "selected subscription is $ACCOUNT_SUB"
[[ "$ACCOUNT_TENANT" == "$WS_TENANT_ID" ]] && ok "tenant selected: $WS_TENANT_ID" || bad "selected tenant is $ACCOUNT_TENANT"

log "2. Required resource providers"
for ns in Microsoft.CognitiveServices Microsoft.Insights Microsoft.OperationalInsights Microsoft.Search Microsoft.Storage; do
  STATE=$(provider_state "$ns")
  [[ "$STATE" == "Registered" ]] && ok "$ns registered" || bad "$ns is $STATE - run: az provider register -n $ns --wait"
done

log "3. Foundry account SKU availability"
if [[ "$(az cognitiveservices account list-skus --kind AIServices --location "$WS_LOCATION" \
     --query "[?name=='S0'] | length(@)" -o tsv 2>/dev/null || echo 0)" -ge 1 ]]; then
  ok "AIServices S0 available in $WS_LOCATION"
else
  bad "AIServices S0 not listed in $WS_LOCATION"
fi

log "4. Model names and quota must still be confirmed on the account"
warn "After creating/reusing the hub, run:"
warn "  az cognitiveservices account list-models -g $WS_RESOURCE_GROUP -n $WS_FOUNDRY_ACCOUNT -o table"
warn "  az cognitiveservices usage list -l $WS_LOCATION -o table"

echo
log "RESULT: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || die "Fix the failures above before running ./run-all.sh."

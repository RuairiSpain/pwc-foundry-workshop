#!/usr/bin/env bash
# Deletes everything. Run it the day after. Asks twice.
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"
preflight

warn "This deletes resource group '$WS_RESOURCE_GROUP' AND $WS_ATTENDEE_COUNT Entra users."
read -r -p "Type the resource group name to confirm: " c1
[[ "$c1" == "$WS_RESOURCE_GROUP" ]] || die "mismatch, aborting"
read -r -p "Delete attendee identities too? (yes/no): " c2
read -r -p "Delete AI-103 sandbox resource groups too? (yes/no): " c3

if [[ "$c2" == "yes" ]]; then
  for i in $(seq -w 1 "$WS_ATTENDEE_COUNT"); do
    upn="${WS_ATTENDEE_PREFIX}${i}@${WS_TENANT_DOMAIN}"
    az ad user delete --id "$upn" 2>/dev/null && log "deleted $upn" || true
  done
fi
if [[ "$c3" == "yes" ]]; then
  : "${WS_AI103_RG_PREFIX:=rg-pwc-ai103}"
  for i in $(seq -w 1 "$WS_ATTENDEE_COUNT"); do
    rg="${WS_AI103_RG_PREFIX}-${i}"
    if az group show -n "$rg" >/dev/null 2>&1; then
      az group delete -n "$rg" --yes --no-wait
      log "sandbox teardown started: $rg"
    fi
  done
fi
az group delete -n "$WS_RESOURCE_GROUP" --yes --no-wait
rm -f "$WS_OUT_DIR/attendees.csv"
log "Teardown started. Roster file removed."

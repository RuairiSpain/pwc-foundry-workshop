#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# AI-103 SANDBOXES  -  run this IN ADDITION to 30-assign-rbac.sh
#
# WHY THIS EXISTS
#   The AI-103 labs (mslearn-ai-agents, mslearn-ai-language, mslearn-ai-vision)
#   instruct every attendee to CREATE THEIR OWN Foundry resource, project,
#   AI Search service, storage account and model deployments. Quote from
#   Exercise 01: "Foundry resource: A valid name for your Foundry resource ...
#   Resource group: Select your resource group, or create a new one".
#
#   That bypasses hub-and-spoke completely. Per the Foundry permissions
#   reference, creating a Foundry account needs Contributor/Owner/Foundry
#   Account Owner at RESOURCE GROUP scope - Foundry User and Foundry Project
#   Manager are both explicitly "No".
#
#   So AI-103 attendees need their own sandbox resource group. This script
#   creates one per attendee and grants Owner on it (and nothing else).
#
# WHY OWNER AND NOT CONTRIBUTOR
#   Contributor can create the resources but has NO data-plane rights, so the
#   attendee could not then create an agent inside the resource they just made.
#   The portal only auto-assigns Foundry User "if the creator of the project
#   has the ability to assign the Foundry User role" - Contributor cannot.
#   Owner scoped to their OWN resource group is the least-friction grant that
#   works, and the blast radius is one empty resource group.
#
# ISOLATION
#   Owner is scoped to rg-<prefix>-<NN> only. It confers nothing on the shared
#   hub, on anyone else's sandbox, or at subscription scope.
# ---------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"
preflight

: "${WS_AI103_RG_PREFIX:=rg-pwc-ai103}"
ROLE_OWNER="8e3af657-a8ff-443c-a75c-2fe8c4bcb635"

ROSTER="$WS_OUT_DIR/attendees.csv"
[[ -f "$ROSTER" ]] || die "roster not found - run 10-create-users.sh first"

warn "This creates $WS_ATTENDEE_COUNT separate resource groups."
warn "Each attendee will deploy their OWN models inside them."
warn "Check subscription quota FIRST: $WS_ATTENDEE_COUNT x per-attendee capacity."
echo

while IFS=, read -r num name upn pw proj; do
  [[ "$num" == "number" ]] && continue
  RG="${WS_AI103_RG_PREFIX}-${num}"
  OID=$(az ad user show --id "$upn" --query id -o tsv 2>/dev/null) \
    || { warn "no such user $upn"; continue; }

  az group create -n "$RG" -l "$WS_LOCATION" \
    --tags purpose=ai103-lab attendee="$num" owner=csa --output none
  log "$RG created"

  az role assignment create --assignee-object-id "$OID" \
    --assignee-principal-type User --role "$ROLE_OWNER" \
    --scope "/subscriptions/${WS_SUBSCRIPTION_ID}/resourceGroups/${RG}" \
    --output none 2>/dev/null \
    && log "  + Owner granted to $upn" || warn "  Owner assignment already present or failed"

  # Quota visibility is subscription-scoped; harmless and needed by the portal.
  az role assignment create --assignee-object-id "$OID" \
    --assignee-principal-type User --role "$ROLE_USAGES_READER" \
    --scope "$WS_SUB_SCOPE" --output none 2>/dev/null || true
done < "$ROSTER"

log "AI-103 sandboxes ready."
log "Attendees create their own Foundry resource INSIDE their own group."
log "Tell them: when a lab says 'create or select a resource group',"
log "they must select ${WS_AI103_RG_PREFIX}-<their number> and NEVER create a new one."

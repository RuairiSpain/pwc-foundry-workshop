#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Grants every permission the labs actually need.
#
# ATTENDEE (human):
#   Reader                          @ hub        see hub + shared models + siblings
#   Foundry Project Manager         @ own spoke  create agents AND connections
#   Cognitive Services OpenAI User  @ hub        memory store embeddings
#   Cognitive Services Usages Reader@ sub        quota visibility
#   AcrPush                         @ rg         push agent container images
#   Monitoring Reader               @ app insights  READ TRACES (Lab 5)
#   Log Analytics Reader            @ workspace  run KQL (Lab 5)
#   [optional] Foundry Agent Consumer @ demo project  invoke instructor agents
#
# PROJECT MANAGED IDENTITY (per spoke):
#   Foundry User                    @ hub        proxy inference to shared models
#   AcrPull                         @ rg         pull image at runtime
#   Log Analytics Reader            @ workspace  telemetry for evaluations
#
# WHY Project Manager and not Foundry User:
#   Every lab declares azure.ai.connection services (the MCP servers). Creating
#   a connection needs .../projects/connections/write at project scope, which
#   Foundry User does NOT have and Foundry Project Manager does. Scoped to the
#   attendee's own spoke, so it grants nothing over anyone else's project.
# ---------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"
preflight

ROSTER="$WS_OUT_DIR/attendees.csv"
[[ -f "$ROSTER" ]] || die "roster not found - run 10-create-users.sh first"

assign () {  # assign <oid> <principalType> <roleId> <scope> <label>
  if az role assignment create --assignee-object-id "$1" --assignee-principal-type "$2" \
       --role "$3" --scope "$4" --output none 2>/dev/null; then
    log "    ok: $5"
  else
    warn "    already present or FAILED: $5"
  fi
}

log "=== Attendee permissions ==="
while IFS=, read -r num name upn pw proj; do
  [[ "$num" == "number" ]] && continue
  OID=$(az ad user show --id "$upn" --query id -o tsv 2>/dev/null) \
    || { warn "no such user $upn"; continue; }
  PROJ_SCOPE="$WS_ACCOUNT_SCOPE/projects/$proj"
  log "$upn"
  assign "$OID" User "$ROLE_READER"                   "$WS_ACCOUNT_SCOPE" "Reader on hub (see shared models + siblings)"
  assign "$OID" User "$ROLE_FOUNDRY_PROJECT_MANAGER"  "$PROJ_SCOPE"       "Foundry Project Manager on own spoke (agents + connections)"
  assign "$OID" User "$ROLE_OPENAI_USER"              "$WS_ACCOUNT_SCOPE" "OpenAI User on hub (memory embeddings)"
  assign "$OID" User "$ROLE_USAGES_READER"            "$WS_SUB_SCOPE"     "Usages Reader (quota)"
  assign "$OID" User "$ROLE_ACR_PUSH"                 "$WS_RG_SCOPE"      "AcrPush (deploy agent images)"
  assign "$OID" User "$ROLE_MONITORING_READER"        "$WS_APPI_SCOPE"    "Monitoring Reader (READ TRACES - Lab 5)"
  assign "$OID" User "$ROLE_LOG_ANALYTICS_READER"     "$WS_LAW_SCOPE"     "Log Analytics Reader (KQL - Lab 5)"

  if [[ -n "$WS_DEMO_PROJECT" ]]; then
    assign "$OID" User "$ROLE_FOUNDRY_AGENT_CONSUMER" \
      "$WS_ACCOUNT_SCOPE/projects/$WS_DEMO_PROJECT" "Agent Consumer on demo project (invoke only)"
  fi
done < "$ROSTER"

log "=== Project managed identities ==="
for i in $(seq -w 1 "$WS_ATTENDEE_COUNT"); do
  proj="${WS_PROJECT_PREFIX}-${i}"
  MI=$(az cognitiveservices account project show -g "$WS_RESOURCE_GROUP" \
        --name "$WS_FOUNDRY_ACCOUNT" --project-name "$proj" \
        --query identity.principalId -o tsv 2>/dev/null)
  if [[ -z "$MI" || "$MI" == "null" ]]; then
    warn "  $proj has no managed identity yet - re-run after the project finishes provisioning"
    continue
  fi
  log "$proj managed identity"
  assign "$MI" ServicePrincipal "$ROLE_FOUNDRY_USER"          "$WS_ACCOUNT_SCOPE" "Foundry User on hub (inference proxy)"
  assign "$MI" ServicePrincipal "$ROLE_ACR_PULL"              "$WS_RG_SCOPE"      "AcrPull (runtime image pull)"
  assign "$MI" ServicePrincipal "$ROLE_LOG_ANALYTICS_READER"  "$WS_LAW_SCOPE"     "Log Analytics Reader (evaluations)"
done

log "RBAC complete. Run ./40-verify.sh to confirm."

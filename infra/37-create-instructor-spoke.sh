#!/usr/bin/env bash
# Creates an instructor spoke project with the same runtime shape as attendees.
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"
preflight

: "${WS_INSTRUCTOR_UPN:=$(az account show --query user.name -o tsv)}"
PROJ="$WS_INSTRUCTOR_PROJECT"
PROJ_SCOPE="$WS_ACCOUNT_SCOPE/projects/$PROJ"

if az cognitiveservices account project show -g "$WS_RESOURCE_GROUP" \
     --name "$WS_FOUNDRY_ACCOUNT" --project-name "$PROJ" >/dev/null 2>&1; then
  log "instructor spoke exists: $PROJ"
else
  az cognitiveservices account project create \
    -g "$WS_RESOURCE_GROUP" --name "$WS_FOUNDRY_ACCOUNT" \
    --project-name "$PROJ" --location "$WS_LOCATION" \
    --assign-identity --output none
  log "created instructor spoke: $PROJ"
fi

OID=$(az ad user show --id "$WS_INSTRUCTOR_UPN" --query id -o tsv 2>/dev/null) \
  || die "cannot resolve instructor user $WS_INSTRUCTOR_UPN"

assign() {
  az role assignment create --assignee-object-id "$OID" --assignee-principal-type User \
    --role "$1" --scope "$2" --output none 2>/dev/null \
    && log "  ok: $3" || warn "  already present or failed: $3"
}

log "granting instructor spoke permissions to $WS_INSTRUCTOR_UPN"
assign "$ROLE_READER"                  "$WS_ACCOUNT_SCOPE" "Reader on hub"
assign "$ROLE_FOUNDRY_PROJECT_MANAGER" "$PROJ_SCOPE"       "Foundry Project Manager on instructor spoke"
assign "$ROLE_OPENAI_USER"             "$WS_ACCOUNT_SCOPE" "OpenAI User on hub"
assign "$ROLE_USAGES_READER"           "$WS_SUB_SCOPE"     "Usages Reader"
assign "$ROLE_ACR_PUSH"                "$WS_RG_SCOPE"      "AcrPush"
assign "$ROLE_MONITORING_READER"       "$WS_APPI_SCOPE"    "Monitoring Reader"
assign "$ROLE_LOG_ANALYTICS_READER"    "$WS_LAW_SCOPE"     "Log Analytics Reader"

MI=$(az cognitiveservices account project show -g "$WS_RESOURCE_GROUP" \
      --name "$WS_FOUNDRY_ACCOUNT" --project-name "$PROJ" \
      --query identity.principalId -o tsv 2>/dev/null)
if [[ -n "$MI" && "$MI" != "null" ]]; then
  az role assignment create --assignee-object-id "$MI" --assignee-principal-type ServicePrincipal \
    --role "$ROLE_FOUNDRY_USER" --scope "$WS_ACCOUNT_SCOPE" --output none 2>/dev/null || true
  az role assignment create --assignee-object-id "$MI" --assignee-principal-type ServicePrincipal \
    --role "$ROLE_ACR_PULL" --scope "$WS_RG_SCOPE" --output none 2>/dev/null || true
  az role assignment create --assignee-object-id "$MI" --assignee-principal-type ServicePrincipal \
    --role "$ROLE_LOG_ANALYTICS_READER" --scope "$WS_LAW_SCOPE" --output none 2>/dev/null || true
  log "instructor project managed identity permissions ready"
else
  warn "instructor project managed identity not visible yet - re-run this script before deploying agents"
fi

log "Instructor endpoint:"
echo "https://${WS_FOUNDRY_ACCOUNT}.services.ai.azure.com/api/projects/${PROJ}"

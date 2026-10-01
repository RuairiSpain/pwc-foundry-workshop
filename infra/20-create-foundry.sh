#!/usr/bin/env bash
# Creates (or reuses) the Foundry hub, deploys the shared models, and creates
# one spoke project per attendee.
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"
preflight

az group create -n "$WS_RESOURCE_GROUP" -l "$WS_LOCATION" --output none
log "resource group ready: $WS_RESOURCE_GROUP"

if az cognitiveservices account show -g "$WS_RESOURCE_GROUP" -n "$WS_FOUNDRY_ACCOUNT" >/dev/null 2>&1; then
  log "reusing existing hub: $WS_FOUNDRY_ACCOUNT"
  KIND=$(az cognitiveservices account show -g "$WS_RESOURCE_GROUP" -n "$WS_FOUNDRY_ACCOUNT" --query kind -o tsv)
  [[ "$KIND" == "AIServices" ]] || die "Existing account kind is '$KIND', not 'AIServices'. \
This workshop needs a Foundry resource (Microsoft.CognitiveServices/accounts, kind AIServices), \
not a classic ML hub. See README 'Which hub do I have?'."
else
  [[ "$WS_EXISTING_HUB" == "true" ]] && warn "WS_EXISTING_HUB=true but no hub found; creating one."
  log "creating hub $WS_FOUNDRY_ACCOUNT"
  az cognitiveservices account create \
    -n "$WS_FOUNDRY_ACCOUNT" -g "$WS_RESOURCE_GROUP" -l "$WS_LOCATION" \
    --kind AIServices --sku S0 --custom-domain "$WS_FOUNDRY_ACCOUNT" \
    --assign-identity --output none
fi

deploy_model () {
  local name="$1" model="$2" version="$3" cap="$4" fmt="${5:-OpenAI}"
  if az cognitiveservices account deployment show -g "$WS_RESOURCE_GROUP" \
       -n "$WS_FOUNDRY_ACCOUNT" --deployment-name "$name" >/dev/null 2>&1; then
    log "deployment exists: $name"; return
  fi
  log "deploying model $name ($model:$version, capacity $cap)"
  az cognitiveservices account deployment create \
    -g "$WS_RESOURCE_GROUP" -n "$WS_FOUNDRY_ACCOUNT" \
    --deployment-name "$name" --model-name "$model" \
    --model-version "$version" --model-format "$fmt" \
    --sku-name GlobalStandard --sku-capacity "$cap" --output none \
    || warn "deployment $name FAILED - check model availability and quota in $WS_LOCATION"
}

deploy_model "$WS_CHAT_MODEL"      "$WS_CHAT_MODEL"      "$WS_CHAT_MODEL_VERSION"   "$WS_CHAT_CAPACITY"
deploy_model "$WS_CHAT_MODEL_B"    "$WS_CHAT_MODEL_B"    "$WS_CHAT_MODEL_B_VERSION" "$WS_CHAT_CAPACITY_B"
deploy_model "$WS_ROUTER_MODEL"    "$WS_ROUTER_MODEL"    "1"                        "$WS_ROUTER_CAPACITY"
deploy_model "$WS_EMBEDDING_MODEL" "$WS_EMBEDDING_MODEL" "1"                        "$WS_EMBEDDING_CAPACITY"

log "creating $WS_ATTENDEE_COUNT spoke projects"
for i in $(seq -w 1 "$WS_ATTENDEE_COUNT"); do
  proj="${WS_PROJECT_PREFIX}-${i}"
  if az cognitiveservices account project show -g "$WS_RESOURCE_GROUP" \
       --name "$WS_FOUNDRY_ACCOUNT" --project-name "$proj" >/dev/null 2>&1; then
    continue
  fi
  az cognitiveservices account project create \
    -g "$WS_RESOURCE_GROUP" --name "$WS_FOUNDRY_ACCOUNT" \
    --project-name "$proj" --location "$WS_LOCATION" \
    --assign-identity --output none && log "  + $proj"
done
log "Foundry topology complete."

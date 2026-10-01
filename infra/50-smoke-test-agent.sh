#!/usr/bin/env bash
# End-to-end smoke test: call the shared model as the signed-in user.
# Run this AS AN ATTENDEE (az login as attendee01) to prove their rights work.
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"
IDX="${1:-01}"
PROJ="${WS_PROJECT_PREFIX}-${IDX}"
ENDPOINT="https://${WS_FOUNDRY_ACCOUNT}.services.ai.azure.com/api/projects/${PROJ}"

log "Project endpoint: $ENDPOINT"
TOKEN=$(az account get-access-token --scope https://ai.azure.com/.default --query accessToken -o tsv) \
  || die "could not get a token - are you signed in?"

log "Calling the chat model as $(az account show --query user.name -o tsv)"
curl -fsS "${ENDPOINT}/responses" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"${WS_CHAT_MODEL}\",\"input\":\"Reply with exactly: workshop ready\"}" \
  | head -c 2000
echo

#!/usr/bin/env bash
# Deploys the four sample agents into every attendee spoke and the instructor spoke.
#
# By default this uses the currently signed-in instructor identity. Students still
# get edit/delete rights because they have Foundry Project Manager on their own
# spoke. To prove student least-privilege, run a single spoke after logging in as
# that attendee:
#   ./60-deploy-agents.sh --projects proj-attendee-01
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"
preflight

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS=(
  "agents/01-hello-prompt-agent"
  "agents/02-hosted-knowledge-agent"
  "agents/03-maf-workflow-router"
  "agents/04-harness-dev-team"
)

PROJECTS=()
DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --projects)
      shift
      while [[ $# -gt 0 && "$1" != --* ]]; do PROJECTS+=("$1"); shift; done
      ;;
    *) die "usage: ./60-deploy-agents.sh [--dry-run] [--projects proj-attendee-01 proj-instructor]" ;;
  esac
done

if [[ "${#PROJECTS[@]}" -eq 0 ]]; then
  for i in $(seq -w 1 "$WS_ATTENDEE_COUNT"); do
    PROJECTS+=("${WS_PROJECT_PREFIX}-${i}")
  done
  PROJECTS+=("$WS_INSTRUCTOR_PROJECT")
fi

require_cmd() { command -v "$1" >/dev/null || die "$1 not found"; }
require_cmd azd

APPI_FILE="$WS_OUT_DIR/appinsights-connection-string.txt"
if [[ -f "$APPI_FILE" ]]; then
  APPI_CS="$(cat "$APPI_FILE")"
elif [[ "$DRY_RUN" == "true" ]]; then
  APPI_CS="InstrumentationKey=00000000-0000-0000-0000-000000000000"
else
  die "missing $APPI_FILE - run 25-observability.sh first"
fi

log "Deploying ${#AGENTS[@]} agents to ${#PROJECTS[@]} project(s)"
for proj in "${PROJECTS[@]}"; do
  endpoint="https://${WS_FOUNDRY_ACCOUNT}.services.ai.azure.com/api/projects/${proj}"
  log "Project: $proj"

  for agent_dir in "${AGENTS[@]}"; do
    name="$(basename "$agent_dir")"
    log "  $name"
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "    FOUNDRY_PROJECT_ENDPOINT=$endpoint"
      echo "    (cd $agent_dir && azd env set ... && azd deploy)"
      continue
    fi

    (
      cd "$ROOT/$agent_dir"
      AZD_ENV="pwc-${proj}-$(basename "$agent_dir")"
      export FOUNDRY_PROJECT_ENDPOINT="$endpoint"
      export APPLICATIONINSIGHTS_CONNECTION_STRING="$APPI_CS"
      export WS_CHAT_MODEL WS_CHAT_MODEL_B WS_ROUTER_MODEL WS_EMBEDDING_MODEL
      export WS_CHAT_MODEL_VERSION WS_CHAT_MODEL_B_VERSION
      export HARNESS_BACKEND="${HARNESS_BACKEND:-magentic}"
      export DEVTEAM_REPO_URL="${DEVTEAM_REPO_URL:-https://github.com/microsoft/mslearn-ai-agents.git}"

      azd env new "$AZD_ENV" --subscription "$WS_SUBSCRIPTION_ID" --location "$WS_LOCATION" --no-prompt >/dev/null 2>&1 \
        || azd env select "$AZD_ENV" --no-prompt >/dev/null
      azd env set FOUNDRY_PROJECT_ENDPOINT "$FOUNDRY_PROJECT_ENDPOINT" >/dev/null
      azd env set APPLICATIONINSIGHTS_CONNECTION_STRING "$APPLICATIONINSIGHTS_CONNECTION_STRING" >/dev/null
      azd env set WS_CHAT_MODEL "$WS_CHAT_MODEL" >/dev/null
      azd env set WS_CHAT_MODEL_B "$WS_CHAT_MODEL_B" >/dev/null
      azd env set WS_ROUTER_MODEL "$WS_ROUTER_MODEL" >/dev/null
      azd env set WS_EMBEDDING_MODEL "$WS_EMBEDDING_MODEL" >/dev/null
      azd env set WS_CHAT_MODEL_VERSION "$WS_CHAT_MODEL_VERSION" >/dev/null
      azd env set WS_CHAT_MODEL_B_VERSION "$WS_CHAT_MODEL_B_VERSION" >/dev/null
      azd env set HARNESS_BACKEND "$HARNESS_BACKEND" >/dev/null
      azd env set DEVTEAM_REPO_URL "$DEVTEAM_REPO_URL" >/dev/null
      azd deploy --no-prompt
    )
  done
done

log "Agent deployment complete."

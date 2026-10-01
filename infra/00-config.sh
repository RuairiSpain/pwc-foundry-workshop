#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Single source of truth for every Azure dependency. Edit ONLY this file.
# All other scripts source it. Override any value from the environment.
# ---------------------------------------------------------------------------
set -euo pipefail

# --- REQUIRED: fill these in -----------------------------------------------
export WS_TENANT_ID="${WS_TENANT_ID:-00000000-0000-0000-0000-000000000000}"
export WS_SUBSCRIPTION_ID="${WS_SUBSCRIPTION_ID:-00000000-0000-0000-0000-000000000000}"
export WS_TENANT_DOMAIN="${WS_TENANT_DOMAIN:-yourtenant.onmicrosoft.com}"

# --- Topology ---------------------------------------------------------------
export WS_RESOURCE_GROUP="${WS_RESOURCE_GROUP:-rg-pwc-agents-lab}"
export WS_LOCATION="${WS_LOCATION:-swedencentral}"
export WS_FOUNDRY_ACCOUNT="${WS_FOUNDRY_ACCOUNT:-fdy-pwc-agents-hub}"
export WS_EXISTING_HUB="${WS_EXISTING_HUB:-true}"    # you said the hub exists
export WS_ATTENDEE_COUNT="${WS_ATTENDEE_COUNT:-35}"  # 25 expected + 10 spare
export WS_ATTENDEE_PREFIX="${WS_ATTENDEE_PREFIX:-attendee}"
export WS_PROJECT_PREFIX="${WS_PROJECT_PREFIX:-proj-attendee}"
export WS_INSTRUCTOR_PROJECT="${WS_INSTRUCTOR_PROJECT:-proj-instructor}"

# --- Models (cheap by design) ----------------------------------------------
# gpt-5.4-mini is the small/cheap serverless chat model used by every lab.
# Verify name+version against your region before the event:
#   az cognitiveservices account list-models -g $RG -n $ACCT -o table
export WS_CHAT_MODEL="${WS_CHAT_MODEL:-gpt-5.4-mini}"
export WS_CHAT_MODEL_VERSION="${WS_CHAT_MODEL_VERSION:-2026-03-17}"
export WS_CHAT_CAPACITY="${WS_CHAT_CAPACITY:-200}"
export WS_CHAT_MODEL_B="${WS_CHAT_MODEL_B:-gpt-5.4-nano}"   # 2nd cheap model for the router lab
export WS_CHAT_MODEL_B_VERSION="${WS_CHAT_MODEL_B_VERSION:-2026-03-17}"
export WS_CHAT_CAPACITY_B="${WS_CHAT_CAPACITY_B:-100}"
export WS_ROUTER_MODEL="${WS_ROUTER_MODEL:-model-router}"
export WS_ROUTER_CAPACITY="${WS_ROUTER_CAPACITY:-100}"
export WS_EMBEDDING_MODEL="${WS_EMBEDDING_MODEL:-text-embedding-3-small}"
export WS_EMBEDDING_CAPACITY="${WS_EMBEDDING_CAPACITY:-50}"

# --- Observability ----------------------------------------------------------
export WS_LAW="${WS_LAW:-law-pwc-agents-lab}"
export WS_APPINSIGHTS="${WS_APPINSIGHTS:-appi-pwc-agents-lab}"

# --- Derived ----------------------------------------------------------------
export WS_ACCOUNT_SCOPE="/subscriptions/${WS_SUBSCRIPTION_ID}/resourceGroups/${WS_RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${WS_FOUNDRY_ACCOUNT}"
export WS_RG_SCOPE="/subscriptions/${WS_SUBSCRIPTION_ID}/resourceGroups/${WS_RESOURCE_GROUP}"
export WS_SUB_SCOPE="/subscriptions/${WS_SUBSCRIPTION_ID}"
export WS_OUT_DIR="${WS_OUT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.out}"
mkdir -p "$WS_OUT_DIR"

# Optional: a shared project holding instructor demo agents that attendees
# should be able to INVOKE but not edit. Leave empty to skip.
export WS_DEMO_PROJECT="${WS_DEMO_PROJECT:-}"

# Role GUIDs (display names are mid-rename; IDs are stable)
export ROLE_FOUNDRY_USER="53ca6127-db72-4b80-b1b0-d745d6d5456d"
export ROLE_FOUNDRY_PROJECT_MANAGER="eadc314b-1a2d-4efa-be10-5d325db5065e"
export ROLE_FOUNDRY_AGENT_CONSUMER="eed3b665-ab3a-47b6-8f48-c9382fb1dad6"
export ROLE_READER="acdd72a7-3385-48ef-bd42-f606fba81ae7"
export ROLE_OPENAI_USER="5e0bd9bd-7b93-4f28-af87-19fc36ad61bd"
export ROLE_USAGES_READER="bba48692-92b0-4667-a9ad-c31c7b334ac2"
export ROLE_ACR_PULL="7f951dda-4ed3-4680-a7ca-43fe172d538d"
export ROLE_ACR_PUSH="8311e382-0749-4cb8-b61a-304f252e45ec"
export ROLE_MONITORING_READER="43d0d8ad-25c7-4714-9337-8ba259a9fe05"
export ROLE_LOG_ANALYTICS_READER="73c42c96-874c-492b-b04d-ab87d138a893"

# Scopes for the observability resources
export WS_APPI_SCOPE="${WS_RG_SCOPE}/providers/Microsoft.Insights/components/${WS_APPINSIGHTS}"
export WS_LAW_SCOPE="${WS_RG_SCOPE}/providers/Microsoft.OperationalInsights/workspaces/${WS_LAW}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

preflight() {
  command -v az >/dev/null || die "Azure CLI not found"
  [[ "$WS_TENANT_ID" != 00000000-* ]] || die "Edit infra/00-config.sh: WS_TENANT_ID is still a placeholder"
  [[ "$WS_SUBSCRIPTION_ID" != 00000000-* ]] || die "Edit infra/00-config.sh: WS_SUBSCRIPTION_ID is still a placeholder"
  az account set --subscription "$WS_SUBSCRIPTION_ID" || die "cannot select subscription"
}

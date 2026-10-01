#!/usr/bin/env bash
# Signs in to Azure and pins this Codespace to YOUR spoke project.
#   ./login.sh 07
set -euo pipefail

N="${1:-}"
if [[ -z "$N" ]]; then
  echo "Usage: ./login.sh <attendee-number>   e.g. ./login.sh 07"
  echo "Your number is on the card you were handed."
  exit 1
fi
N=$(printf '%02d' "$((10#$N))")

: "${WS_TENANT_ID:?WS_TENANT_ID not set - ask the instructor}"
: "${WS_TENANT_DOMAIN:?WS_TENANT_DOMAIN not set - ask the instructor}"
ACCOUNT="${WS_FOUNDRY_ACCOUNT:-fdy-pwc-agents-hub}"
PREFIX="${WS_PROJECT_PREFIX:-proj-attendee}"
PROJECT="${PREFIX}-${N}"
UPN="attendee${N}@${WS_TENANT_DOMAIN}"

echo "============================================================"
echo " Signing in as: $UPN"
echo " Your project:  $PROJECT"
echo "============================================================"
echo
echo "A code will appear below. Open https://microsoft.com/devicelogin"
echo "in a NEW BROWSER TAB, paste the code, and sign in as $UPN"
echo "with the password on your card."
echo

# Device code flow: the only login that works reliably in a browser Codespace.
az login --use-device-code --tenant "$WS_TENANT_ID" --output none
az account set --subscription "${WS_SUBSCRIPTION_ID}"
azd auth login --use-device-code --tenant-id "$WS_TENANT_ID"

ENDPOINT="https://${ACCOUNT}.services.ai.azure.com/api/projects/${PROJECT}"

cat >> ~/.bashrc <<EOF

# --- PwC workshop (added by login.sh) ---
export ATTENDEE_NUMBER=${N}
export FOUNDRY_PROJECT_NAME=${PROJECT}
export FOUNDRY_PROJECT_ENDPOINT=${ENDPOINT}
export WS_CHAT_MODEL=${WS_CHAT_MODEL:-gpt-5.4-mini}
EOF

export ATTENDEE_NUMBER="$N"
export FOUNDRY_PROJECT_NAME="$PROJECT"
export FOUNDRY_PROJECT_ENDPOINT="$ENDPOINT"

azd ai project set "$PROJECT" 2>/dev/null || echo "[i] set your project in azd manually if needed"

echo
echo "Signed in as: $(az account show --query user.name -o tsv)"
echo "Project endpoint: $FOUNDRY_PROJECT_ENDPOINT"
echo
echo "Checking your access..."
if az cognitiveservices account project show -g "${WS_RESOURCE_GROUP:-rg-pwc-agents-lab}" \
     --name "$ACCOUNT" --project-name "$PROJECT" >/dev/null 2>&1; then
  echo "  OK - you can see your project."
else
  echo "  [!] Could not read your project. Tell the instructor your number."
fi
echo
echo "Run:  source ~/.bashrc   then open workshop/LAB-00-START-HERE.md"

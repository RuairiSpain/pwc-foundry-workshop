#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# SHARED AI SEARCH for the AI-103 Foundry IQ lab (Exercise 04)
#
# The lab tells each attendee to create their own Search service and storage
# account - which needs Contributor at RG scope that they do not have.
#
# Instead: YOU create ONE Search service and ONE storage account, upload the
# Contoso PDFs once, and hand out the two keys. Attendees then do only the
# Foundry-side steps (knowledge base + connection + agent), all of which their
# Foundry Project Manager role on their own spoke already permits.
#
# WHY ONE S1 SERVICE
#   Max indexes per service: Free=3, Basic=15, S1=50, S2=200.
#   35 attendees x 1 knowledge base each = 35 indexes -> S1 (50) fits.
#   Basic (15) does NOT. Free (3) certainly does not.
#   S1 is ~$245/month; for a 4-day workshop that is roughly $33.
# ---------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"
preflight

: "${WS_SEARCH_NAME:=srch-pwc-ai103-$RANDOM}"
: "${WS_SEARCH_SKU:=standard}"          # 'standard' == S1, 50 indexes
: "${WS_STORAGE_NAME:=stpwcai103$RANDOM}"
: "${WS_SEARCH_CONTAINER:=contosoproducts}"

log "Creating search service $WS_SEARCH_NAME (SKU $WS_SEARCH_SKU, 50 index limit)"
az search service create -n "$WS_SEARCH_NAME" -g "$WS_RESOURCE_GROUP" \
  -l "$WS_LOCATION" --sku "$WS_SEARCH_SKU" --partition-count 1 --replica-count 1 \
  --output none 2>/dev/null || log "search service exists"

# The lab uses key auth. Allow BOTH keys and RBAC, as Exercise 04 instructs.
az search service update -n "$WS_SEARCH_NAME" -g "$WS_RESOURCE_GROUP" \
  --auth-options apiKeyOnly --output none 2>/dev/null \
  || warn "could not set auth options - set 'API Access control = Both' in the portal"

log "Creating storage account $WS_STORAGE_NAME"
az storage account create -n "$WS_STORAGE_NAME" -g "$WS_RESOURCE_GROUP" \
  -l "$WS_LOCATION" --sku Standard_LRS --kind StorageV2 --output none 2>/dev/null \
  || log "storage account exists"

STOR_KEY=$(az storage account keys list -n "$WS_STORAGE_NAME" -g "$WS_RESOURCE_GROUP" \
  --query "[0].value" -o tsv)

az storage container create -n "$WS_SEARCH_CONTAINER" \
  --account-name "$WS_STORAGE_NAME" --account-key "$STOR_KEY" --output none 2>/dev/null \
  || log "container exists"

log "Downloading and uploading the Contoso product PDFs"
TMP=$(mktemp -d)
if curl -fsSL -o "$TMP/contoso-products.zip" \
   "https://github.com/MicrosoftLearning/mslearn-ai-agents/raw/main/Labfiles/04-integrate-agent-with-foundry-iq/data/contoso-products.zip"; then
  unzip -q -o "$TMP/contoso-products.zip" -d "$TMP/pdfs"
  find "$TMP/pdfs" -name '*.pdf' -print0 | while IFS= read -r -d '' f; do
    az storage blob upload --account-name "$WS_STORAGE_NAME" --account-key "$STOR_KEY" \
      -c "$WS_SEARCH_CONTAINER" -f "$f" -n "$(basename "$f")" --overwrite --output none
    log "  uploaded $(basename "$f")"
  done
else
  warn "could not download the lab PDFs - upload them manually to $WS_SEARCH_CONTAINER"
fi
rm -rf "$TMP"

SEARCH_KEY=$(az search admin-key show -g "$WS_RESOURCE_GROUP" \
  --service-name "$WS_SEARCH_NAME" --query primaryKey -o tsv 2>/dev/null)

CARD="$WS_OUT_DIR/foundry-iq-handout.txt"
cat > "$CARD" <<EOF
=====================================================================
AI-103 Exercise 04 - Foundry IQ  |  SHARED RESOURCES (do NOT create your own)
=====================================================================
Search service name : $WS_SEARCH_NAME
Search endpoint     : https://${WS_SEARCH_NAME}.search.windows.net
Search admin key    : $SEARCH_KEY

Storage account     : $WS_STORAGE_NAME
Container           : $WS_SEARCH_CONTAINER
Storage key         : $STOR_KEY

The 3 Contoso product PDFs are already uploaded. Do not upload them again.

>>> NAME YOUR KNOWLEDGE BASE  ks-contosoproducts-<YOUR NUMBER>
>>> e.g. ks-contosoproducts-07
>>> All 35 of you share one search service. Identical names will collide.
=====================================================================
EOF
log "Handout written to $CARD"
warn "It contains live keys. Delete it after the workshop."

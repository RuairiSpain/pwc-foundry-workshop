#!/usr/bin/env bash
# Log Analytics + App Insights + diagnostic settings on the hub, so every agent
# has logging switched on from the very first run.
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"
preflight

az monitor log-analytics workspace create \
  -g "$WS_RESOURCE_GROUP" -n "$WS_LAW" -l "$WS_LOCATION" --output none 2>/dev/null \
  || log "workspace exists"
LAW_ID=$(az monitor log-analytics workspace show -g "$WS_RESOURCE_GROUP" -n "$WS_LAW" --query id -o tsv)

az monitor app-insights component create \
  --app "$WS_APPINSIGHTS" -g "$WS_RESOURCE_GROUP" -l "$WS_LOCATION" \
  --workspace "$LAW_ID" --output none 2>/dev/null || log "app insights exists"

APPI_CS=$(az monitor app-insights component show --app "$WS_APPINSIGHTS" \
  -g "$WS_RESOURCE_GROUP" --query connectionString -o tsv)
echo "$APPI_CS" > "$WS_OUT_DIR/appinsights-connection-string.txt"

log "enabling diagnostics on the Foundry hub"
az monitor diagnostic-settings create \
  --name "foundry-to-law" \
  --resource "$WS_ACCOUNT_SCOPE" \
  --workspace "$LAW_ID" \
  --logs   '[{"categoryGroup":"allLogs","enabled":true}]' \
  --metrics '[{"category":"AllMetrics","enabled":true}]' \
  --output none 2>/dev/null || log "diagnostic setting exists"

log "App Insights connection string saved to $WS_OUT_DIR/appinsights-connection-string.txt"
log "Set it for the agents:  azd env set APPLICATIONINSIGHTS_CONNECTION_STRING \"\$(cat $WS_OUT_DIR/appinsights-connection-string.txt)\""

#!/usr/bin/env bash
# Gives each attendee Reader on THEIR VM only, plus Reader on the Bastion.
# They sign in to Windows with the LOCAL credentials on their card, so no
# Entra join / AAD login extension is needed.
source "$(dirname "${BASH_SOURCE[0]}")/00-labvm-config.sh"
preflight

ROLE_READER="acdd72a7-3385-48ef-bd42-f606fba81ae7"
BASTION_ID=$(az network bastion show -g "$LAB_RG" -n "$LAB_BASTION" --query id -o tsv 2>/dev/null || true)
VNET_ID=$(az network vnet show -g "$LAB_RG" -n "$LAB_VNET" --query id -o tsv)

for i in $(seq -w 1 "$LAB_COUNT"); do
  VM="${LAB_PREFIX}-${i}"
  UPN="attendee${i}@${WS_TENANT_DOMAIN}"
  OID=$(az ad user show --id "$UPN" --query id -o tsv 2>/dev/null) || { warn "no user $UPN"; continue; }
  VM_ID=$(az vm show -g "$LAB_RG" -n "$VM" --query id -o tsv 2>/dev/null) || { warn "no vm $VM"; continue; }

  az role assignment create --assignee-object-id "$OID" --assignee-principal-type User \
    --role "$ROLE_READER" --scope "$VM_ID" --output none 2>/dev/null \
    && log "$UPN -> Reader on $VM" || warn "$UPN VM role already present"

  # Bastion + VNet reader are required for the portal Connect blade to work.
  [[ -n "$BASTION_ID" ]] && az role assignment create --assignee-object-id "$OID" \
    --assignee-principal-type User --role "$ROLE_READER" --scope "$BASTION_ID" \
    --output none 2>/dev/null || true
  az role assignment create --assignee-object-id "$OID" --assignee-principal-type User \
    --role "$ROLE_READER" --scope "$VNET_ID" --output none 2>/dev/null || true
done
log "Access granted."

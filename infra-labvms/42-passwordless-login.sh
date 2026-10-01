#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# PASSWORDLESS SIGN-IN (the real answer to "can we auto-login?")
#
# Windows auto-logon does NOT help with Bastion: RDP authenticates at the
# protocol handshake, before Windows auto-logon would ever run. Attendees
# would still face a credential prompt.
#
# What DOES remove the prompt: Entra ID authentication for Bastion portal RDP.
#   "Portal connections use passwordless authentication - you sign in with your
#    Entra ID credentials and don't need a local VM password."
# Minimum SKU for portal RDP: Basic (what we already have).
#
# Requirements this script satisfies:
#   - AADLoginForWindows extension on every VM  (Windows Server 2022+ : OK)
#   - Virtual Machine User Login role for each attendee on THEIR VM
#   - Reader on the VM, its NIC, the Bastion and the VNet
#
# CAVEAT: Entra ID auth for RDP in the portal is PUBLIC PREVIEW. Keep the
# shared local password on the attendee card as a fallback.
# ---------------------------------------------------------------------------
source "$(dirname "${BASH_SOURCE[0]}")/00-labvm-config.sh"
preflight

ROLE_VM_USER_LOGIN="fb879df8-f326-4884-b1cf-06f3ad86be52"
ROLE_READER="acdd72a7-3385-48ef-bd42-f606fba81ae7"

log "Installing AADLoginForWindows on all lab VMs (~5 min)"
for i in $(seq -w 1 "$LAB_COUNT") ; do
  VM="${LAB_PREFIX}-${i}"
  (
    az vm extension set -g "$LAB_RG" --vm-name "$VM" \
      --name AADLoginForWindows --publisher Microsoft.Azure.ActiveDirectory \
      --output none 2>/dev/null && log "  OK   $VM" || warn "  FAIL $VM"
  ) &
  while [[ $(jobs -rp | wc -l) -ge 8 ]]; do sleep 1; done
done
wait
# your test VM too, so you can test the attendee experience properly
az vm extension set -g "$LAB_RG" --vm-name "$LAB_TEST_VM" \
  --name AADLoginForWindows --publisher Microsoft.Azure.ActiveDirectory \
  --output none 2>/dev/null && log "  OK   $LAB_TEST_VM" || warn "  FAIL $LAB_TEST_VM"

BASTION_ID=$(az network bastion show -g "$LAB_RG" -n "$LAB_BASTION" --query id -o tsv 2>/dev/null || true)
VNET_ID=$(az network vnet show -g "$LAB_RG" -n "$LAB_VNET" --query id -o tsv)

log "Granting Virtual Machine User Login + the Reader roles Bastion requires"
for i in $(seq -w 1 "$LAB_COUNT"); do
  VM="${LAB_PREFIX}-${i}"
  UPN="attendee${i}@${WS_TENANT_DOMAIN}"
  OID=$(az ad user show --id "$UPN" --query id -o tsv 2>/dev/null) || { warn "no user $UPN"; continue; }
  VM_ID=$(az vm show -g "$LAB_RG" -n "$VM" --query id -o tsv 2>/dev/null) || continue
  NIC_ID=$(az vm show -g "$LAB_RG" -n "$VM" --query "networkProfile.networkInterfaces[0].id" -o tsv 2>/dev/null)

  az role assignment create --assignee-object-id "$OID" --assignee-principal-type User \
    --role "$ROLE_VM_USER_LOGIN" --scope "$VM_ID" --output none 2>/dev/null || true
  # Reader on the NIC is easy to miss and breaks the Connect blade without it.
  [[ -n "$NIC_ID" ]] && az role assignment create --assignee-object-id "$OID" \
    --assignee-principal-type User --role "$ROLE_READER" --scope "$NIC_ID" \
    --output none 2>/dev/null || true
  [[ -n "$BASTION_ID" ]] && az role assignment create --assignee-object-id "$OID" \
    --assignee-principal-type User --role "$ROLE_READER" --scope "$BASTION_ID" \
    --output none 2>/dev/null || true
  az role assignment create --assignee-object-id "$OID" --assignee-principal-type User \
    --role "$ROLE_READER" --scope "$VNET_ID" --output none 2>/dev/null || true
  log "  $UPN -> passwordless on $VM"
done

echo
log "Done. On the Bastion Connect blade, attendees should now see"
log "  'Microsoft Entra ID (Preview)' as an authentication option."
warn "TEST THIS on $LAB_TEST_VM before you rely on it - it is public preview."
warn "Tell attendees to allow pop-ups for  cdn.bastion.azure.com"

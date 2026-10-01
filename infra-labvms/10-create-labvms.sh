#!/usr/bin/env bash
# Creates the VNet, Bastion, and one Windows VM per attendee.
# Run time: ~20-30 minutes for 35 VMs (they build in parallel).
source "$(dirname "${BASH_SOURCE[0]}")/00-labvm-config.sh"
preflight

START=$(date +%s)
log "Creating resource group $LAB_RG in $LAB_LOCATION"
az group create -n "$LAB_RG" -l "$LAB_LOCATION" --tags purpose=ai103-labs --output none

log "Creating network"
az network vnet create -g "$LAB_RG" -n "$LAB_VNET" \
  --address-prefix 10.20.0.0/16 \
  --subnet-name "$LAB_SUBNET" --subnet-prefix 10.20.1.0/24 --output none 2>/dev/null || log "vnet exists"

# Bastion needs a subnet named EXACTLY AzureBastionSubnet, /26 or larger.
az network vnet subnet create -g "$LAB_RG" --vnet-name "$LAB_VNET" \
  -n AzureBastionSubnet --address-prefix 10.20.0.0/26 --output none 2>/dev/null || log "bastion subnet exists"

az network public-ip create -g "$LAB_RG" -n "${LAB_BASTION}-pip" \
  --sku Standard --allocation-method Static --output none 2>/dev/null || log "pip exists"

log "Creating Bastion ($LAB_BASTION_SKU) - this takes ~10 minutes, running in background"
az network bastion create -g "$LAB_RG" -n "$LAB_BASTION" \
  --public-ip-address "${LAB_BASTION}-pip" --vnet-name "$LAB_VNET" \
  --location "$LAB_LOCATION" --sku "$LAB_BASTION_SKU" --no-wait --output none 2>/dev/null \
  || warn "bastion create failed or already exists"

# Deny inbound RDP from the internet. Bastion reaches the VM over the VNet.
log "Creating NSG (no inbound from internet)"
az network nsg create -g "$LAB_RG" -n nsg-labvms --output none 2>/dev/null || true
az network vnet subnet update -g "$LAB_RG" --vnet-name "$LAB_VNET" \
  -n "$LAB_SUBNET" --network-security-group nsg-labvms --output none 2>/dev/null || true

CSV="$LAB_OUT/labvm-credentials.csv"
echo "number,vm_name,username,password,schedule" > "$CSV"

log "Creating $LAB_COUNT attendee VMs"
log "  auto-started each training day: 01-$(printf '%02d' "$LAB_AUTO_COUNT")"
log "  reserve/manual start only:       $(printf '%02d' $((LAB_AUTO_COUNT + 1)))-$(printf '%02d' "$LAB_COUNT")"
for i in $(seq -w 1 "$LAB_COUNT"); do
  VM="${LAB_PREFIX}-${i}"
  if (( 10#$i <= LAB_AUTO_COUNT )); then
    SCHEDULE="auto"
  else
    SCHEDULE="reserve"
  fi
  echo "${i},${VM},${LAB_ADMIN},${LAB_PASSWORD},${SCHEDULE}" >> "$CSV"
  az vm create -g "$LAB_RG" -n "$VM" \
    --image "$LAB_IMAGE" --size "$LAB_VM_SIZE" \
    --admin-username "$LAB_ADMIN" --admin-password "$LAB_PASSWORD" \
    --vnet-name "$LAB_VNET" --subnet "$LAB_SUBNET" \
    --public-ip-address "" --nsg "" \
    --storage-sku "$LAB_DISK_SKU" --os-disk-size-gb 128 \
    --tags attendee="$i" purpose=ai103-labs schedule="$SCHEDULE" \
    --no-wait --output none &
  while [[ $(jobs -rp | wc -l) -ge 10 ]]; do sleep 1; done
done
wait

log "Creating YOUR test VM $LAB_TEST_VM (tagged schedule=manual - never auto-started)"
echo "test,${LAB_TEST_VM},${LAB_ADMIN},${LAB_PASSWORD},manual" >> "$CSV"
az vm create -g "$LAB_RG" -n "$LAB_TEST_VM" \
  --image "$LAB_IMAGE" --size "$LAB_TEST_VM_SIZE" \
  --admin-username "$LAB_ADMIN" --admin-password "$LAB_PASSWORD" \
  --vnet-name "$LAB_VNET" --subnet "$LAB_SUBNET" \
  --public-ip-address "" --nsg "" \
  --storage-sku "$LAB_DISK_SKU" --os-disk-size-gb 128 \
  --tags purpose=ai103-labs schedule=manual owner=instructor \
  --no-wait --output none

log "Waiting for all VMs to reach Succeeded..."
az vm wait -g "$LAB_RG" --created --ids $(az vm list -g "$LAB_RG" --query "[].id" -o tsv) 2>/dev/null || true

log "Credentials written to $CSV"
warn "That file contains plaintext passwords. Delete it after the workshop."
log "Elapsed: $(( ($(date +%s) - START) / 60 )) minutes"
log "NEXT: ./20-install-tools.sh"
log "One shared password for every VM: $LAB_PASSWORD"

#!/usr/bin/env bash
# Start reserve attendee VMs only. By default starts all reserves; pass numbers
# to start specific late-arrival VMs, e.g. ./start-reserve-vms.sh 26 27.
source "$(dirname "${BASH_SOURCE[0]}")/00-labvm-config.sh"
preflight

if [[ $# -gt 0 ]]; then
  TARGETS=("$@")
else
  START=$((LAB_AUTO_COUNT + 1))
  mapfile -t TARGETS < <(seq -w "$START" "$LAB_COUNT")
fi

IDS=()
for n in "${TARGETS[@]}"; do
  i=$(printf '%02d' "$((10#$n))")
  VM="${LAB_PREFIX}-${i}"
  ID=$(az vm show -g "$LAB_RG" -n "$VM" --query id -o tsv 2>/dev/null) || {
    warn "no reserve VM found for $i ($VM)"
    continue
  }
  SCHEDULE=$(az vm show -g "$LAB_RG" -n "$VM" --query "tags.schedule" -o tsv 2>/dev/null)
  [[ "$SCHEDULE" == "reserve" ]] || warn "$VM is tagged schedule=$SCHEDULE, not reserve"
  IDS+=("$ID")
done

[[ "${#IDS[@]}" -gt 0 ]] || die "no reserve VMs selected"
log "Starting ${#IDS[@]} reserve VM(s)"
az vm start --ids "${IDS[@]}" --no-wait
log "Started. Allow ~5 minutes before they are reachable."

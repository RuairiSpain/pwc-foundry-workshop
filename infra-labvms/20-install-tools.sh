#!/usr/bin/env bash
# Pushes setup-labvm.ps1 to every VM using run-command.
# ~10-15 minutes for 35 VMs. Idempotent - safe to re-run for stragglers.
#   ./20-install-tools.sh          all VMs
#   ./20-install-tools.sh 07 12    just those two
#   ./20-install-tools.sh test     just the instructor test VM
source "$(dirname "${BASH_SOURCE[0]}")/00-labvm-config.sh"
preflight

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/setup-labvm.ps1"
[[ -f "$SCRIPT" ]] || die "setup-labvm.ps1 not found"

if [[ $# -gt 0 ]]; then
  TARGETS=("$@")
else
  mapfile -t TARGETS < <(seq -w 1 "$LAB_COUNT"; echo test)
fi

log "Installing VS Code, Python 3.13, Git, az CLI and azd on ${#TARGETS[@]} VM(s)"
log "This takes 10-15 minutes. Progress appears as each VM finishes."

for i in "${TARGETS[@]}"; do
  if [[ "$i" == "test" ]]; then VM="$LAB_TEST_VM"; else VM="${LAB_PREFIX}-${i}"; fi
  (
    if az vm run-command invoke -g "$LAB_RG" -n "$VM" \
         --command-id RunPowerShellScript --scripts "@$SCRIPT" --output none 2>/dev/null; then
      log "  OK   $VM"
    else
      warn "  FAIL $VM  - re-run: ./20-install-tools.sh $i"
    fi
  ) &
  # Throttle to 8 concurrent; more than that hits ARM rate limits.
  while [[ $(jobs -rp | wc -l) -ge 8 ]]; do sleep 2; done
done
wait

log "Done. Before the session, connect to ONE VM and confirm:"
log "  - C:\\labsetup.log ends with 'setup complete'"
log "  - code --version, python --version, az version, azd version all respond"

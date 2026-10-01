#!/usr/bin/env bash
# Creates WS_ATTENDEE_COUNT Entra users and writes the printable roster.
# Idempotent: existing users are skipped, not recreated.
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"
preflight

ROSTER="$WS_OUT_DIR/attendees.csv"
log "Generating roster for $WS_ATTENDEE_COUNT attendees"
python3 -c "
import sys; sys.path.insert(0, '$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)')
from workshop_toolkit.config import WorkshopConfig
from workshop_toolkit.identity import build_attendees, roster_to_csv
cfg = WorkshopConfig.from_env()
print(roster_to_csv(build_attendees(cfg)), end='')
" > "$ROSTER"
log "Roster written to $ROSTER"

created=0; skipped=0
while IFS=, read -r num name upn pw proj; do
  [[ "$num" == "number" ]] && continue
  if az ad user show --id "$upn" >/dev/null 2>&1; then
    warn "exists, skipping: $upn"; skipped=$((skipped+1)); continue
  fi
  az ad user create \
    --display-name "$name" \
    --user-principal-name "$upn" \
    --mail-nickname "${WS_ATTENDEE_PREFIX}${num}" \
    --password "$pw" \
    --force-change-password-next-sign-in false \
    --output none
  log "created $upn"
  created=$((created+1))
done < "$ROSTER"

log "Users created: $created, already existed: $skipped"
warn "Roster contains plaintext passwords. Delete $ROSTER after the workshop."

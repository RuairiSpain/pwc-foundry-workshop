#!/usr/bin/env bash
# Read-only check that the four sample agents exist in each requested project.
source "$(dirname "${BASH_SOURCE[0]}")/00-config.sh"
preflight

EXPECTED_AGENTS=(
  pwc-hello-agent
  pwc-knowledge-agent
  pwc-workflow-agent
  pwc-dev-team-agent
)

PROJECTS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --projects)
      shift
      while [[ $# -gt 0 && "$1" != --* ]]; do PROJECTS+=("$1"); shift; done
      ;;
    *) die "usage: ./65-verify-agents.sh [--projects proj-attendee-01 proj-instructor]" ;;
  esac
done

if [[ "${#PROJECTS[@]}" -eq 0 ]]; then
  for i in $(seq -w 1 "$WS_ATTENDEE_COUNT"); do
    PROJECTS+=("${WS_PROJECT_PREFIX}-${i}")
  done
  PROJECTS+=("$WS_INSTRUCTOR_PROJECT")
fi

TOKEN=$(az account get-access-token --scope https://ai.azure.com/.default --query accessToken -o tsv) \
  || die "could not get https://ai.azure.com token"

PASS=0; FAIL=0
ok()  { printf '  \033[1;32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[1;31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

for proj in "${PROJECTS[@]}"; do
  log "$proj"
  endpoint="https://${WS_FOUNDRY_ACCOUNT}.services.ai.azure.com/api/projects/${proj}"
  body=$(curl -fsS "${endpoint}/agents?api-version=2026-05-01" \
    -H "Authorization: Bearer ${TOKEN}" 2>/dev/null) || {
      bad "$proj: cannot list agents"
      continue
    }
  for agent in "${EXPECTED_AGENTS[@]}"; do
    if grep -q "\"name\"[[:space:]]*:[[:space:]]*\"${agent}\"" <<<"$body"; then
      ok "$proj: $agent"
    else
      bad "$proj: missing $agent"
    fi
  done
done

echo
log "RESULT: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || die "Fix missing agents before the workshop."

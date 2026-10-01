#!/usr/bin/env bash
# One command to build the whole environment.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
./05-check-prereqs.sh
./10-create-users.sh
./20-create-foundry.sh
./25-observability.sh
./30-assign-rbac.sh
./37-create-instructor-spoke.sh
./40-verify.sh

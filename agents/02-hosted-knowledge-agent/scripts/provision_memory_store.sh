#!/usr/bin/env sh
# Creates the Foundry memory store the agent reads and writes, then records its
# name in the azd environment so azure.yaml's ${MEMORY_STORE_NAME} resolves.
set -e
STORE_NAME="${MEMORY_STORE_NAME:-pwc-workshop-memory}"
echo "==> provisioning memory store '$STORE_NAME'"
python3 "$(dirname "$0")/provision_memory_store.py" "$STORE_NAME"
azd env set MEMORY_STORE_NAME "$STORE_NAME"
echo "==> memory store ready"

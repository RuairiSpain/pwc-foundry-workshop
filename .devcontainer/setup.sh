#!/usr/bin/env bash
set -euo pipefail
echo "==> Installing azd"
curl -fsSL https://aka.ms/install-azd.sh | bash

echo "==> Installing the Foundry azd extensions (agent, project, toolbox, skill, routine, connection, inspector)"
azd ext install microsoft.foundry || echo "[!] extension install failed - retry manually: azd ext install microsoft.foundry"

echo "==> Python packages"
pip install --quiet --upgrade pip
pip install --quiet \
  "agent-framework" "agent-framework-foundry" \
  "azure-ai-projects" "azure-identity" "azure-monitor-opentelemetry" \
  pyyaml pytest pytest-cov || echo "[!] some packages failed; see requirements files"

echo
echo "================================================================"
echo "  PwC Foundry Agents Workshop - ready"
echo
echo "  Next:   ./login.sh <your attendee number>     e.g. ./login.sh 07"
echo "  Then:   cat workshop/LAB-00-START-HERE.md"
echo "================================================================"

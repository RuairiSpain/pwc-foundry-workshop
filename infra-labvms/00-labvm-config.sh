#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# LAB VM CONFIG - browser-accessed Windows desktops for locked-down laptops.
# Edit this file only. Everything else sources it.
# ---------------------------------------------------------------------------
set -euo pipefail

export WS_SUBSCRIPTION_ID="${WS_SUBSCRIPTION_ID:-00000000-0000-0000-0000-000000000000}"
export WS_TENANT_DOMAIN="${WS_TENANT_DOMAIN:-yourtenant.onmicrosoft.com}"

export LAB_RG="${LAB_RG:-rg-pwc-labvms}"
export LAB_LOCATION="${LAB_LOCATION:-westeurope}"
export LAB_COUNT="${LAB_COUNT:-35}"          # one VM per possible attendee
export LAB_AUTO_COUNT="${LAB_AUTO_COUNT:-25}" # auto-start each morning; the rest are reserves
export LAB_PREFIX="${LAB_PREFIX:-labvm}"
export LAB_ADMIN="${LAB_ADMIN:-labuser}"
# ONE shared local password across all lab VMs. Attendees can only launch
# Bastion against their OWN VM (Reader is scoped per-VM), so a shared password
# does not let them reach anyone else's machine. This is the single biggest
# reduction in joining friction.
export LAB_PASSWORD="${LAB_PASSWORD:-PwcAgents-2026-Lab!}"

# Your personal test VM. Excluded from all scheduling - you start/stop it.
export LAB_TEST_VM="${LAB_TEST_VM:-labvm-test}"
# The attendee identity you will sign in AS when testing student permissions.
export LAB_TEST_IDENTITY="${LAB_TEST_IDENTITY:-attendee35}"

# Training days and times (Madrid). Used by 41-schedule-power.sh
export LAB_DAYS="${LAB_DAYS:-2026-09-30 2026-10-02 2026-10-07}"
export LAB_START_TIME="${LAB_START_TIME:-08:30}"
export LAB_STOP_TIME="${LAB_STOP_TIME:-14:00}"
export LAB_TIMEZONE="${LAB_TIMEZONE:-Romance Standard Time}"
export LAB_TZ_OFFSET="${LAB_TZ_OFFSET:-+02:00}"       # CEST
export LAB_AUTOMATION="${LAB_AUTOMATION:-aa-pwc-labs}"

# B2ms = 2 vCPU / 8 GB burstable. Enough for VS Code + Python + az/azd
# while keeping 35 VMs inside common 100-vCPU lab subscription quotas.
export LAB_VM_SIZE="${LAB_VM_SIZE:-Standard_B2ms}"
export LAB_TEST_VM_SIZE="${LAB_TEST_VM_SIZE:-Standard_B4ms}"
export LAB_IMAGE="${LAB_IMAGE:-MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest}"
export LAB_DISK_SKU="${LAB_DISK_SKU:-StandardSSD_LRS}"

export LAB_VNET="${LAB_VNET:-vnet-pwc-labs}"
export LAB_SUBNET="${LAB_SUBNET:-snet-labvms}"
export LAB_BASTION="${LAB_BASTION:-bas-pwc-labs}"
# Basic SKU: 2 instances x 20 concurrent RDP = 40 sessions. Fits 35 attendees.
# Developer SKU is free but allows only ONE VM connection at a time - unusable.
export LAB_BASTION_SKU="${LAB_BASTION_SKU:-Basic}"

export LAB_OUT="${LAB_OUT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.out}"
mkdir -p "$LAB_OUT"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

preflight() {
  command -v az >/dev/null || die "Azure CLI not found"
  [[ "$WS_SUBSCRIPTION_ID" != 00000000-* ]] || die "Edit 00-labvm-config.sh first"
  [[ "$LAB_AUTO_COUNT" -le "$LAB_COUNT" ]] || die "LAB_AUTO_COUNT cannot exceed LAB_COUNT"
  [[ "$LAB_AUTO_COUNT" -ge 1 ]] || die "LAB_AUTO_COUNT must be at least 1"
  az account set --subscription "$WS_SUBSCRIPTION_ID" || die "cannot select subscription"
}

#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-common.sh"

log "checking Tailscale status on ${SSH_TARGET}"
ssh "${SSH_TARGET}" 'tailscale status --json'

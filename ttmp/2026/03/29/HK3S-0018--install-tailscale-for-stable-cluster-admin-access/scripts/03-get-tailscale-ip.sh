#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-common.sh"

log "getting Tailscale IPv4 for ${SSH_TARGET}"
ssh "${SSH_TARGET}" "tailscale ip -4"

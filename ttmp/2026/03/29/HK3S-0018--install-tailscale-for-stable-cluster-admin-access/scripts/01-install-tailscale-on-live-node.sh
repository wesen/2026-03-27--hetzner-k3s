#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-common.sh"

log "installing Tailscale on ${SSH_TARGET}"
ssh "${SSH_TARGET}" '
  set -euo pipefail
  curl -fsSL https://tailscale.com/install.sh | sh
  systemctl enable --now tailscaled
  tailscale up --accept-routes=false --accept-dns=true --ssh
'

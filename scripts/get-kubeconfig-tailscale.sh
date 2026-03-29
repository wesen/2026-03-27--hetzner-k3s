#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: get-kubeconfig-tailscale.sh [tailscale-host]

Fetch /etc/rancher/k3s/k3s.yaml from the node over Tailscale and rewrite the
server endpoint away from 127.0.0.1.

Host resolution order:
  1. first CLI argument
  2. $K3S_TAILSCALE_DNS
  3. $K3S_TAILSCALE_IP

Optional environment:
  K3S_TAILNET_KUBECONFIG   output path override
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

HOST="${1:-${K3S_TAILSCALE_DNS:-${K3S_TAILSCALE_IP:-}}}"

if [[ -z "${HOST}" ]]; then
  usage
  exit 1
fi

safe_host="${HOST//\//-}"
safe_host="${safe_host//:/-}"
safe_host="${safe_host// /-}"

OUTFILE="${K3S_TAILNET_KUBECONFIG:-kubeconfig-${safe_host}.yaml}"
SSH_OPTIONS=(
  -o StrictHostKeyChecking=accept-new
)

scp "${SSH_OPTIONS[@]}" "root@${HOST}:/etc/rancher/k3s/k3s.yaml" "${OUTFILE}"

python - <<PY
from pathlib import Path
p = Path(${OUTFILE@Q})
host = ${HOST@Q}
text = p.read_text()
text = text.replace("127.0.0.1", host)
p.write_text(text)
print(f"wrote {p}")
PY

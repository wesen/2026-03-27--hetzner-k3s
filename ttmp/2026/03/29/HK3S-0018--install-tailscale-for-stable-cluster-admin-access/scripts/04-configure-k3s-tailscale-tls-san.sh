#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-common.sh"

TAILSCALE_IP="${TAILSCALE_IP:-$(ssh "${SSH_TARGET}" 'tailscale ip -4')}"
TAILSCALE_DNS="${TAILSCALE_DNS:-$(ssh "${SSH_TARGET}" "tailscale status --json | jq -r '.Self.DNSName' | sed 's/\\.$//'")}"

log "configuring k3s tls-san entries for ${TAILSCALE_IP} and ${TAILSCALE_DNS}"
ssh "${SSH_TARGET}" "cat >/etc/rancher/k3s/config.yaml <<'EOF'
write-kubeconfig-mode: \"0644\"
tls-san:
  - ${TAILSCALE_IP}
  - ${TAILSCALE_DNS}
EOF
systemctl restart k3s
until kubectl get nodes >/dev/null 2>&1; do sleep 5; done
kubectl get nodes -o wide"

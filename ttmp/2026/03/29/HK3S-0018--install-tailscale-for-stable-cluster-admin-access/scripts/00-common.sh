#!/usr/bin/env bash
set -euo pipefail

TICKET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${TICKET_ROOT}/../../../../../../.." && pwd)"
SERVER_IP="${SERVER_IP:-91.98.46.169}"
SSH_TARGET="${SSH_TARGET:-root@${SERVER_IP}}"

log() {
  printf '[hk3s-0018] %s\n' "$*"
}

#!/usr/bin/env bash

set -euo pipefail

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || {
    echo "missing required environment variable: $name" >&2
    exit 1
  }
}

require_cmd docker
require_cmd ssh

require_env K3S_NODE_HOST

coinvault_repo="${COINVAULT_REPO_DIR:-/home/manuel/code/gec/2026-03-16--gec-rag}"
image_name="${COINVAULT_IMAGE_NAME:-coinvault:hk3s-0007}"
ssh_target="${K3S_NODE_USER:-root}@${K3S_NODE_HOST}"

docker build -t "${image_name}" "${coinvault_repo}"
docker save "${image_name}" | ssh "${ssh_target}" 'k3s ctr images import - >/dev/null'
ssh "${ssh_target}" "k3s ctr images ls | grep '${image_name%%:*}'"

echo "built and imported ${image_name} to ${ssh_target}"

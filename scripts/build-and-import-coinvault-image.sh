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
temp_build_root="$(mktemp -d)"

cleanup() {
  rm -rf "${temp_build_root}"
}

trap cleanup EXIT

prepare_build_context() {
  rsync -a --delete \
    --exclude '.git' \
    --exclude 'node_modules' \
    --exclude 'web/node_modules' \
    --exclude 'tmp' \
    --exclude 'var' \
    "${coinvault_repo}/" "${temp_build_root}/"

  (
    cd "${temp_build_root}"
    go mod edit -dropreplace=github.com/go-go-golems/geppetto
    go mod edit -dropreplace=github.com/go-go-golems/pinocchio
    go mod tidy
  )
}

prepare_build_context

docker build -t "${image_name}" "${temp_build_root}"
docker save "${image_name}" | ssh "${ssh_target}" 'k3s ctr images import - >/dev/null'
ssh "${ssh_target}" "k3s ctr images ls | grep '${image_name%%:*}'"

echo "built and imported ${image_name} to ${ssh_target}"

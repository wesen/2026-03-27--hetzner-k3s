#!/usr/bin/env bash

set -euo pipefail

require_cmd() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || {
    echo "required command not found: $name" >&2
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

require_cmd vault
require_cmd gh
require_cmd base64

require_env VAULT_ADDR
require_env VAULT_TOKEN
require_env GITHUB_DEPLOY_PAT

kv_mount_path="${VAULT_KV_MOUNT_PATH:-kv}"
secret_path="${COINVAULT_IMAGE_PULL_SECRET_PATH:-apps/coinvault/prod/image-pull}"
github_username="${GITHUB_DEPLOY_USERNAME:-$(gh api user --jq '.login')}"
registry_server="${GITHUB_DEPLOY_SERVER:-ghcr.io}"

auth_b64="$(printf '%s:%s' "${github_username}" "${GITHUB_DEPLOY_PAT}" | base64 | tr -d '\n')"

vault kv put "${kv_mount_path}/${secret_path}" \
  server="${registry_server}" \
  username="${github_username}" \
  password="${GITHUB_DEPLOY_PAT}" \
  auth="${auth_b64}" >/dev/null

echo "seeded ${kv_mount_path}/${secret_path} into ${VAULT_ADDR}"
echo "registry server: ${registry_server}"
echo "github username: ${github_username}"
echo "no secret values were printed"

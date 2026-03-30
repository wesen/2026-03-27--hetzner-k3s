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
require_cmd htpasswd

require_env VAULT_ADDR
require_env VAULT_TOKEN
require_env PRETEXT_TRACE_BASIC_AUTH_PASSWORD

kv_mount_path="${VAULT_KV_MOUNT_PATH:-kv}"
secret_path="${PRETEXT_TRACE_BASIC_AUTH_SECRET_PATH:-apps/pretext-trace/prod/ingress-basic-auth}"
username="${PRETEXT_TRACE_BASIC_AUTH_USERNAME:-friend}"

users_line="$(htpasswd -nbB "${username}" "${PRETEXT_TRACE_BASIC_AUTH_PASSWORD}")"

vault kv put "${kv_mount_path}/${secret_path}" \
  users="${users_line}" \
  username="${username}" \
  source="bootstrap-pretext-trace-basic-auth-secret.sh" >/dev/null

echo "seeded ${kv_mount_path}/${secret_path} into ${VAULT_ADDR}"
echo "basic auth username: ${username}"
echo "no secret values were printed"

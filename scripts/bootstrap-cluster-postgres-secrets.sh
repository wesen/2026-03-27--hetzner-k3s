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

require_cmd vault
require_cmd jq
require_cmd openssl

require_env VAULT_ADDR
require_env VAULT_TOKEN

kv_mount_path="${VAULT_KV_MOUNT_PATH:-kv}"
secret_path="${POSTGRES_CLUSTER_SECRET_PATH:-infra/postgres/cluster}"
platform_database="${POSTGRES_PLATFORM_DATABASE:-platform}"
platform_username="${POSTGRES_PLATFORM_USERNAME:-platform_admin}"
service_host="${POSTGRES_SERVICE_HOST:-postgres.postgres.svc.cluster.local}"
service_port="${POSTGRES_SERVICE_PORT:-5432}"
force_rotate="${FORCE_ROTATE:-0}"

random_secret() {
  openssl rand -base64 24 | tr -d '\n'
}

load_existing() {
  if vault kv get -format=json "${kv_mount_path}/${secret_path}" >/tmp/postgres-secret.json 2>/dev/null; then
    jq -r '.data.data' /tmp/postgres-secret.json
  else
    echo '{}'
  fi
}

existing="$(load_existing)"

read_value() {
  local key="$1"
  jq -r --arg key "$key" '.[$key] // ""' <<<"$existing"
}

set_or_generate() {
  local key="$1"
  local current
  current="$(read_value "$key")"
  if [[ "${force_rotate}" != "0" || -z "$current" ]]; then
    random_secret
  else
    printf '%s' "$current"
  fi
}

postgres_password="$(set_or_generate "postgres-password")"

vault kv put "${kv_mount_path}/${secret_path}" \
  postgres-password="${postgres_password}" \
  postgres-db="${platform_database}" \
  postgres-user="${platform_username}" \
  service-host="${service_host}" \
  service-port="${service_port}" >/dev/null

echo "bootstrapped ${kv_mount_path}/${secret_path}"
echo "  service host: ${service_host}"
echo "  platform database: ${platform_database}"
echo "  platform username: ${platform_username}"
echo "  password was generated or preserved without printing its value"

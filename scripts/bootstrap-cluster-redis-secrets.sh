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
secret_path="${REDIS_CLUSTER_SECRET_PATH:-infra/redis/cluster}"
service_host="${REDIS_SERVICE_HOST:-redis.redis.svc.cluster.local}"
service_port="${REDIS_SERVICE_PORT:-6379}"
force_rotate="${FORCE_ROTATE:-0}"

random_secret() {
  openssl rand -base64 24 | tr -d '\n'
}

load_existing() {
  if vault kv get -format=json "${kv_mount_path}/${secret_path}" >/tmp/redis-secret.json 2>/dev/null; then
    jq -r '.data.data' /tmp/redis-secret.json
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

redis_password="$(set_or_generate "redis-password")"

vault kv put "${kv_mount_path}/${secret_path}" \
  redis-password="${redis_password}" \
  service-host="${service_host}" \
  service-port="${service_port}" >/dev/null

echo "bootstrapped ${kv_mount_path}/${secret_path}"
echo "  service host: ${service_host}"
echo "  password was generated or preserved without printing its value"

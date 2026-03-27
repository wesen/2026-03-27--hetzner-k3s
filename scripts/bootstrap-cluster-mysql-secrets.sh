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
secret_path="${MYSQL_CLUSTER_SECRET_PATH:-infra/mysql/cluster}"
coinvault_database="${MYSQL_COINVAULT_DATABASE:-gec}"
coinvault_username="${MYSQL_COINVAULT_USERNAME:-coinvault_ro}"
service_host="${MYSQL_SERVICE_HOST:-mysql.mysql.svc.cluster.local}"
service_port="${MYSQL_SERVICE_PORT:-3306}"
force_rotate="${FORCE_ROTATE:-0}"

random_secret() {
  openssl rand -base64 24 | tr -d '\n'
}

load_existing() {
  if vault kv get -format=json "${kv_mount_path}/${secret_path}" >/tmp/mysql-secret.json 2>/dev/null; then
    jq -r '.data.data' /tmp/mysql-secret.json
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

root_password="$(set_or_generate "mysql-root-password")"
user_password="$(set_or_generate "mysql-password")"
replication_password="$(set_or_generate "mysql-replication-password")"

vault kv put "${kv_mount_path}/${secret_path}" \
  mysql-root-password="${root_password}" \
  mysql-password="${user_password}" \
  mysql-replication-password="${replication_password}" \
  coinvault-database="${coinvault_database}" \
  coinvault-username="${coinvault_username}" \
  service-host="${service_host}" \
  service-port="${service_port}" >/dev/null

echo "bootstrapped ${kv_mount_path}/${secret_path}"
echo "  service host: ${service_host}"
echo "  coinvault database: ${coinvault_database}"
echo "  coinvault username: ${coinvault_username}"
echo "  passwords were generated or preserved without printing values"

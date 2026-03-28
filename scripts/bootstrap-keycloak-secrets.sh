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
database_secret_path="${KEYCLOAK_DATABASE_SECRET_PATH:-apps/keycloak/prod/database}"
bootstrap_secret_path="${KEYCLOAK_BOOTSTRAP_SECRET_PATH:-apps/keycloak/prod/bootstrap-admin}"
database_name="${KEYCLOAK_DATABASE_NAME:-keycloak}"
database_username="${KEYCLOAK_DATABASE_USERNAME:-keycloak_app}"
service_host="${KEYCLOAK_DATABASE_HOST:-postgres.postgres.svc.cluster.local}"
service_port="${KEYCLOAK_DATABASE_PORT:-5432}"
bootstrap_username="${KEYCLOAK_BOOTSTRAP_USERNAME:-bootstrap-admin}"
force_rotate="${FORCE_ROTATE:-0}"

random_secret() {
  openssl rand -base64 24 | tr -d '\n'
}

load_existing() {
  local path="$1"
  local cache_file="$2"
  if vault kv get -format=json "${kv_mount_path}/${path}" >"${cache_file}" 2>/dev/null; then
    jq -r '.data.data' "${cache_file}"
  else
    echo '{}'
  fi
}

database_existing="$(load_existing "${database_secret_path}" /tmp/keycloak-database-secret.json)"
bootstrap_existing="$(load_existing "${bootstrap_secret_path}" /tmp/keycloak-bootstrap-secret.json)"

read_value() {
  local existing="$1"
  local key="$2"
  jq -r --arg key "$key" '.[$key] // ""' <<<"${existing}"
}

set_or_generate() {
  local existing="$1"
  local key="$2"
  local current
  current="$(read_value "${existing}" "${key}")"
  if [[ "${force_rotate}" != "0" || -z "${current}" ]]; then
    random_secret
  else
    printf '%s' "${current}"
  fi
}

database_password="$(set_or_generate "${database_existing}" "password")"
bootstrap_password="$(set_or_generate "${bootstrap_existing}" "password")"
current_bootstrap_username="$(read_value "${bootstrap_existing}" "username")"

if [[ -z "${current_bootstrap_username}" ]]; then
  current_bootstrap_username="${bootstrap_username}"
fi

vault kv put "${kv_mount_path}/${database_secret_path}" \
  database="${database_name}" \
  username="${database_username}" \
  password="${database_password}" \
  service-host="${service_host}" \
  service-port="${service_port}" >/dev/null

vault kv put "${kv_mount_path}/${bootstrap_secret_path}" \
  username="${current_bootstrap_username}" \
  password="${bootstrap_password}" >/dev/null

echo "bootstrapped ${kv_mount_path}/${database_secret_path}"
echo "  database: ${database_name}"
echo "  username: ${database_username}"
echo "  service host: ${service_host}"
echo "bootstrapped ${kv_mount_path}/${bootstrap_secret_path}"
echo "  bootstrap username: ${current_bootstrap_username}"
echo "  passwords were generated or preserved without printing values"

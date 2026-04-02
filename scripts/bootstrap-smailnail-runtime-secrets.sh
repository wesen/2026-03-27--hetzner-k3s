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
require_cmd jq
require_cmd openssl
require_cmd python3

require_env VAULT_ADDR
require_env VAULT_TOKEN
require_env SMAILNAIL_OIDC_CLIENT_SECRET

kv_mount_path="${VAULT_KV_MOUNT_PATH:-kv}"
secret_path="${SMAILNAIL_RUNTIME_SECRET_PATH:-apps/smailnail/prod/runtime}"
database_name="${SMAILNAIL_DATABASE:-smailnail}"
database_user="${SMAILNAIL_USERNAME:-smailnail_app}"
service_host="${SMAILNAIL_SERVICE_HOST:-postgres.postgres.svc.cluster.local}"
service_port="${SMAILNAIL_SERVICE_PORT:-5432}"
encryption_key_id="${SMAILNAIL_ENCRYPTION_KEY_ID:-prod-smailnail}"
force_rotate="${FORCE_ROTATE:-0}"

random_password() {
  openssl rand -base64 24 | tr -d '\n'
}

random_key_base64() {
  openssl rand -base64 32 | tr -d '\n'
}

load_existing() {
  if vault kv get -format=json "${kv_mount_path}/${secret_path}" >/tmp/smailnail-runtime-secret.json 2>/dev/null; then
    jq -c '.data.data' /tmp/smailnail-runtime-secret.json
  else
    echo '{}'
  fi
}

read_value() {
  local payload="$1"
  local key="$2"
  jq -r --arg key "$key" '.[$key] // ""' <<<"${payload}"
}

set_or_generate() {
  local current="$1"
  local generator="$2"

  if [[ "${force_rotate}" != "0" || -z "${current}" ]]; then
    "${generator}"
  else
    printf '%s' "${current}"
  fi
}

existing="$(load_existing)"
db_password="$(set_or_generate "$(read_value "${existing}" "password")" random_password)"
encryption_key_base64="$(set_or_generate "$(read_value "${existing}" "encryption_key_base64")" random_key_base64)"

dsn="$(
  DATABASE_USER="${database_user}" \
  DATABASE_PASSWORD="${db_password}" \
  DATABASE_HOST="${service_host}" \
  DATABASE_PORT="${service_port}" \
  DATABASE_NAME="${database_name}" \
  python3 - <<'PY'
import os
from urllib.parse import quote

user = quote(os.environ["DATABASE_USER"], safe="")
password = quote(os.environ["DATABASE_PASSWORD"], safe="")
host = os.environ["DATABASE_HOST"]
port = os.environ["DATABASE_PORT"]
name = quote(os.environ["DATABASE_NAME"], safe="")
print(f"postgres://{user}:{password}@{host}:{port}/{name}?sslmode=disable")
PY
)"

vault kv put "${kv_mount_path}/${secret_path}" \
  database="${database_name}" \
  username="${database_user}" \
  password="${db_password}" \
  dsn="${dsn}" \
  encryption_key_id="${encryption_key_id}" \
  encryption_key_base64="${encryption_key_base64}" \
  oidc_client_secret="${SMAILNAIL_OIDC_CLIENT_SECRET}" \
  source="bootstrap-smailnail-runtime-secrets.sh" >/dev/null

echo "seeded ${kv_mount_path}/${secret_path} into ${VAULT_ADDR}"
echo "database: ${database_name}"
echo "database user: ${database_user}"
echo "database host: ${service_host}:${service_port}"
echo "encryption key id: ${encryption_key_id}"
echo "no secret values were printed"

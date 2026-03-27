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

require_env SOURCE_VAULT_ADDR
require_env SOURCE_VAULT_TOKEN
require_env DEST_VAULT_ADDR
require_env DEST_VAULT_TOKEN

source_kv_mount="${SOURCE_VAULT_KV_MOUNT_PATH:-kv}"
dest_kv_mount="${DEST_VAULT_KV_MOUNT_PATH:-kv}"
runtime_secret_path="${COINVAULT_RUNTIME_SECRET_PATH:-apps/coinvault/prod/runtime}"
pinocchio_secret_path="${COINVAULT_PINOCCHIO_SECRET_PATH:-apps/coinvault/prod/pinocchio}"
k3s_public_url="${COINVAULT_K3S_PUBLIC_URL:-https://coinvault.yolo.scapegoat.dev}"

read_secret() {
  local addr="$1"
  local token="$2"
  local mount="$3"
  local path="$4"

  VAULT_ADDR="$addr" VAULT_TOKEN="$token" \
    vault kv get -format=json "${mount}/${path}" | jq -c '.data.data'
}

write_runtime_secret() {
  local payload="$1"
  local session_secret oidc_client_secret oidc_issuer_url oidc_client_id
  local gec_mysql_host gec_mysql_port gec_mysql_database gec_mysql_ro_user gec_mysql_ro_password

  session_secret="$(jq -r '.session_secret' <<<"$payload")"
  oidc_client_secret="$(jq -r '.oidc_client_secret' <<<"$payload")"
  oidc_issuer_url="$(jq -r '.oidc_issuer_url // empty' <<<"$payload")"
  oidc_client_id="$(jq -r '.oidc_client_id // empty' <<<"$payload")"
  gec_mysql_host="$(jq -r '.gec_mysql_host' <<<"$payload")"
  gec_mysql_port="$(jq -r '.gec_mysql_port' <<<"$payload")"
  gec_mysql_database="$(jq -r '.gec_mysql_database' <<<"$payload")"
  gec_mysql_ro_user="$(jq -r '.gec_mysql_ro_user' <<<"$payload")"
  gec_mysql_ro_password="$(jq -r '.gec_mysql_ro_password' <<<"$payload")"

  VAULT_ADDR="$DEST_VAULT_ADDR" VAULT_TOKEN="$DEST_VAULT_TOKEN" \
    vault kv put "${dest_kv_mount}/${runtime_secret_path}" \
      session_secret="${session_secret}" \
      oidc_client_secret="${oidc_client_secret}" \
      public_app_url="${k3s_public_url}" \
      oidc_issuer_url="${oidc_issuer_url}" \
      oidc_client_id="${oidc_client_id}" \
      gec_mysql_host="${gec_mysql_host}" \
      gec_mysql_port="${gec_mysql_port}" \
      gec_mysql_database="${gec_mysql_database}" \
      gec_mysql_ro_user="${gec_mysql_ro_user}" \
      gec_mysql_ro_password="${gec_mysql_ro_password}" >/dev/null
}

write_pinocchio_secret() {
  local payload="$1"
  local profiles_yaml config_yaml

  profiles_yaml="$(jq -r '.profiles_yaml' <<<"$payload")"
  config_yaml="$(jq -r '.config_yaml' <<<"$payload")"

  VAULT_ADDR="$DEST_VAULT_ADDR" VAULT_TOKEN="$DEST_VAULT_TOKEN" \
    vault kv put "${dest_kv_mount}/${pinocchio_secret_path}" \
      profiles_yaml="${profiles_yaml}" \
      config_yaml="${config_yaml}" >/dev/null
}

runtime_payload="$(read_secret "$SOURCE_VAULT_ADDR" "$SOURCE_VAULT_TOKEN" "$source_kv_mount" "$runtime_secret_path")"
pinocchio_payload="$(read_secret "$SOURCE_VAULT_ADDR" "$SOURCE_VAULT_TOKEN" "$source_kv_mount" "$pinocchio_secret_path")"

write_runtime_secret "$runtime_payload"
write_pinocchio_secret "$pinocchio_payload"

echo "seeded ${dest_kv_mount}/${runtime_secret_path} into ${DEST_VAULT_ADDR}"
echo "seeded ${dest_kv_mount}/${pinocchio_secret_path} into ${DEST_VAULT_ADDR}"
echo "public app url set to ${k3s_public_url}"
echo "no secret values were printed"

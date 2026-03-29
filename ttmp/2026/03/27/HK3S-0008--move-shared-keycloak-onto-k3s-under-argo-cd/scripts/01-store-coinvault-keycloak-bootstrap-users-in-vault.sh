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

read_tfvar_string() {
  local file="$1"
  local key="$2"
  sed -nE "s/^${key}[[:space:]]*=[[:space:]]*\"(.*)\"$/\\1/p" "$file" | tail -n 1
}

require_cmd vault
require_cmd terraform
require_cmd sed

require_env VAULT_ADDR
require_env VAULT_TOKEN

tf_env_dir="${COINVAULT_KEYCLOAK_TF_ENV_DIR:-/home/manuel/code/wesen/terraform/keycloak/apps/coinvault/envs/k3s-parallel}"
tfvars_file="${tf_env_dir}/terraform.tfvars"
kv_mount_path="${VAULT_KV_MOUNT_PATH:-kv}"
secret_base_path="${COINVAULT_KEYCLOAK_USERS_SECRET_BASE_PATH:-apps/coinvault/prod/keycloak-users}"
issuer_url="${COINVAULT_KEYCLOAK_ISSUER_URL:-https://auth.yolo.scapegoat.dev/realms/coinvault}"

[[ -f "$tfvars_file" ]] || {
  echo "missing terraform tfvars file: $tfvars_file" >&2
  exit 1
}

wesen_password="$(read_tfvar_string "$tfvars_file" wesen_password)"
clint_password="$(read_tfvar_string "$tfvars_file" clint_password)"

[[ -n "$wesen_password" ]] || {
  echo "failed to load wesen_password from $tfvars_file" >&2
  exit 1
}

[[ -n "$clint_password" ]] || {
  echo "failed to load clint_password from $tfvars_file" >&2
  exit 1
}

pushd "$tf_env_dir" >/dev/null
wesen_subject="$(terraform output -raw wesen_user_id)"
clint_subject="$(terraform output -raw clint_user_id)"
popd >/dev/null

vault kv put "${kv_mount_path}/${secret_base_path}/wesen" \
  username="wesen" \
  email="wesen@ruinwesen.com" \
  first_name="Manuel" \
  last_name="Odendahl" \
  issuer_url="${issuer_url}" \
  realm="coinvault" \
  subject="${wesen_subject}" \
  password="${wesen_password}" >/dev/null

vault kv put "${kv_mount_path}/${secret_base_path}/clint" \
  username="clint" \
  email="clint@goldeneaglecoin.com" \
  first_name="Clint" \
  last_name="Stelfox" \
  issuer_url="${issuer_url}" \
  realm="coinvault" \
  subject="${clint_subject}" \
  password="${clint_password}" >/dev/null

echo "seeded ${kv_mount_path}/${secret_base_path}/wesen"
echo "seeded ${kv_mount_path}/${secret_base_path}/clint"
echo "issuer: ${issuer_url}"
echo "no secret values were printed"

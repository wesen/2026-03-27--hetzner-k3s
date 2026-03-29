#!/usr/bin/env bash

set -euo pipefail

readonly TICKET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT="$(cd "${TICKET_ROOT}/../../../../.." && pwd)"
readonly DEFAULT_KUBECONFIG_PATH="${REPO_ROOT}/kubeconfig-91.98.46.169.yaml"

log() {
  printf '[hk3s-0017] %s\n' "$*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$1" >&2
    exit 1
  }
}

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || {
    printf 'missing required environment variable: %s\n' "$name" >&2
    exit 1
  }
}

setup_kubeconfig() {
  export KUBECONFIG="${KUBECONFIG_PATH:-$DEFAULT_KUBECONFIG_PATH}"
  [[ -f "${KUBECONFIG}" ]] || {
    printf 'kubeconfig not found: %s\n' "${KUBECONFIG}" >&2
    exit 1
  }
}

vault_kv_get_json() {
  local path="$1"
  VAULT_ADDR="${VAULT_ADDR}" VAULT_TOKEN="${VAULT_TOKEN}" \
    vault kv get -format=json "kv/${path}" | jq -c '.data.data'
}

load_vault_token_if_needed() {
  if [[ -z "${VAULT_TOKEN:-}" && -f "${HOME}/.vault-token" ]]; then
    export VAULT_TOKEN
    VAULT_TOKEN="$(<"${HOME}/.vault-token")"
  fi
}

load_backup_storage_env() {
  require_cmd aws
  require_cmd vault
  require_cmd jq
  require_env VAULT_ADDR
  load_vault_token_if_needed
  require_env VAULT_TOKEN

  local payload
  payload="$(vault_kv_get_json "infra/backups/object-storage")"

  export BACKUP_STORAGE_BUCKET_NAME
  BACKUP_STORAGE_BUCKET_NAME="$(jq -r '."bucket-name"' <<<"${payload}")"
  export BACKUP_STORAGE_ENDPOINT_URL
  BACKUP_STORAGE_ENDPOINT_URL="$(jq -r '."storage-endpoint"' <<<"${payload}")"
  export BACKUP_STORAGE_REGION
  BACKUP_STORAGE_REGION="$(jq -r '."storage-region"' <<<"${payload}")"
  export AWS_ACCESS_KEY_ID
  AWS_ACCESS_KEY_ID="$(jq -r '."access-key"' <<<"${payload}")"
  export AWS_SECRET_ACCESS_KEY
  AWS_SECRET_ACCESS_KEY="$(jq -r '."secret-key"' <<<"${payload}")"
  export AWS_DEFAULT_REGION="${BACKUP_STORAGE_REGION}"
}

latest_backup_object_key() {
  local prefix="$1"
  aws --endpoint-url "${BACKUP_STORAGE_ENDPOINT_URL}" s3 ls "s3://${BACKUP_STORAGE_BUCKET_NAME}/${prefix}" --recursive \
    | awk '{print $4}' \
    | tail -n 1
}

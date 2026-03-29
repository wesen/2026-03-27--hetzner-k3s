#!/usr/bin/env bash

set -euo pipefail

readonly TICKET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT="$(cd "${TICKET_ROOT}/../../../../../../.." && pwd)"
readonly DEFAULT_KUBECONFIG_PATH="${REPO_ROOT}/kubeconfig-91.98.46.169.yaml"

log() {
  printf '[hk3s-0009] %s\n' "$*"
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


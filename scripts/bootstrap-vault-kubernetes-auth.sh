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

require_env VAULT_ADDR
require_env VAULT_TOKEN

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
policy_dir="${repo_root}/vault/policies/kubernetes"
role_dir="${repo_root}/vault/roles/kubernetes"

kubernetes_auth_path="${VAULT_KUBERNETES_AUTH_PATH:-kubernetes}"
kubernetes_host="${VAULT_KUBERNETES_HOST:-https://kubernetes.default.svc:443}"
kv_mount_path="${VAULT_KV_MOUNT_PATH:-kv}"

ensure_auth_mount() {
  if ! vault auth list -format=json | jq -e --arg key "${kubernetes_auth_path}/" '.[$key]' >/dev/null; then
    vault auth enable -path="${kubernetes_auth_path}" kubernetes >/dev/null
  fi
}

ensure_kv_mount() {
  if ! vault secrets list -format=json | jq -e --arg key "${kv_mount_path}/" '.[$key]' >/dev/null; then
    vault secrets enable -path="${kv_mount_path}" -version=2 kv >/dev/null
  fi
}

configure_kubernetes_auth() {
  vault write "auth/${kubernetes_auth_path}/config" \
    kubernetes_host="${kubernetes_host}" >/dev/null
}

write_policies() {
  local file
  for file in "${policy_dir}"/*.hcl; do
    local policy_name
    policy_name="$(basename "${file}" .hcl)"
    vault policy write "${policy_name}" "${file}" >/dev/null
  done
}

write_roles() {
  local file
  for file in "${role_dir}"/*.json; do
    local role_name
    role_name="$(basename "${file}" .json)"
    vault write "auth/${kubernetes_auth_path}/role/${role_name}" @"${file}" >/dev/null
  done
}

seed_smoke_secrets() {
  vault kv put "${kv_mount_path}/apps/vault-auth-smoke/dev/demo" \
    username="vault-auth-smoke" \
    password="smoke-secret" \
    source="bootstrap-vault-kubernetes-auth.sh" >/dev/null

  vault kv put "${kv_mount_path}/apps/vso-smoke/dev/demo" \
    username="vso-smoke" \
    password="vso-secret" \
    source="bootstrap-vault-kubernetes-auth.sh" >/dev/null

  vault kv put "${kv_mount_path}/apps/vault-auth-other/dev/demo" \
    username="vault-auth-other" \
    password="deny-me" \
    source="bootstrap-vault-kubernetes-auth.sh" >/dev/null
}

ensure_kv_mount
ensure_auth_mount
configure_kubernetes_auth
write_policies
write_roles
seed_smoke_secrets

echo "vault kubernetes auth bootstrap complete"
echo "  auth path: auth/${kubernetes_auth_path}"
echo "  kv mount: ${kv_mount_path}/"
echo "  policies: $(find "${policy_dir}" -maxdepth 1 -type f -name '*.hcl' | wc -l | tr -d ' ')"
echo "  roles: $(find "${role_dir}" -maxdepth 1 -type f -name '*.json' | wc -l | tr -d ' ')"

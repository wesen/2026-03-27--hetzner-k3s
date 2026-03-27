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
require_cmd kubectl
require_cmd jq

require_env VAULT_ADDR
require_env KUBECONFIG

role="${VAULT_K8S_SMOKE_ROLE:-vault-auth-smoke}"
namespace="${VAULT_K8S_SMOKE_NAMESPACE:-vault-auth-smoke}"
service_account="${VAULT_K8S_SMOKE_SERVICE_ACCOUNT:-vault-auth-smoke}"
kubernetes_auth_path="${VAULT_KUBERNETES_AUTH_PATH:-kubernetes}"
kv_mount_path="${VAULT_KV_MOUNT_PATH:-kv}"
allowed_path="${VAULT_K8S_ALLOWED_PATH:-apps/vault-auth-smoke/dev/demo}"
denied_path="${VAULT_K8S_DENIED_PATH:-apps/vault-auth-other/dev/demo}"

jwt="$(kubectl -n "${namespace}" create token "${service_account}")"
login_json="$(vault write -format=json "auth/${kubernetes_auth_path}/login" role="${role}" jwt="${jwt}")"
client_token="$(printf '%s' "${login_json}" | jq -r '.auth.client_token')"

if [[ -z "${client_token}" || "${client_token}" == "null" ]]; then
  echo "vault kubernetes auth login did not return a client token" >&2
  exit 1
fi

allowed_json="$(VAULT_TOKEN="${client_token}" vault kv get -mount="${kv_mount_path}" -format=json "${allowed_path}")"

if ! printf '%s' "${allowed_json}" | jq -e '.data.data.username == "vault-auth-smoke"' >/dev/null; then
  echo "allowed path returned unexpected data" >&2
  exit 1
fi

if VAULT_TOKEN="${client_token}" vault kv get -mount="${kv_mount_path}" "${denied_path}" >/dev/null 2>&1; then
  echo "denied-path read unexpectedly succeeded" >&2
  exit 1
fi

echo "vault kubernetes auth validation passed"
echo "  role: ${role}"
echo "  namespace/serviceaccount: ${namespace}/${service_account}"
echo "  allowed path: ${kv_mount_path}/${allowed_path}"
echo "  denied path: ${kv_mount_path}/${denied_path}"

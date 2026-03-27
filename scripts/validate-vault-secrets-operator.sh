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

require_cmd kubectl
require_cmd vault
require_cmd jq

require_env KUBECONFIG
require_env VAULT_ADDR
require_env VAULT_TOKEN

namespace="${VSO_SMOKE_NAMESPACE:-vault-secrets-operator-smoke}"
secret_name="${VSO_SMOKE_SECRET_NAME:-vso-smoke-secret}"
source_path="${VSO_SMOKE_SOURCE_PATH:-kv/apps/vso-smoke/dev/demo}"
failure_name="${VSO_FAILURE_NAME:-vso-smoke-denied}"

wait_for_secret() {
  local key="$1"
  local expected="$2"
  local attempts=24
  local value

  for _ in $(seq 1 "${attempts}"); do
    value="$(
      kubectl -n "${namespace}" get secret "${secret_name}" -o jsonpath="{.data.${key}}" 2>/dev/null \
        | base64 -d 2>/dev/null || true
    )"
    if [[ "${value}" == "${expected}" ]]; then
      return 0
    fi
    sleep 5
  done

  echo "timed out waiting for ${secret_name}.${key} to become ${expected}" >&2
  return 1
}

kubectl -n argocd get application vault-secrets-operator -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'
kubectl -n argocd get application vault-secrets-operator-smoke -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'

kubectl -n vault-secrets-operator-system rollout status deployment/vault-secrets-operator-controller-manager --timeout=120s >/dev/null

initial_password="$(vault kv get -format=json "${source_path}" | jq -r '.data.data.password')"
wait_for_secret password "${initial_password}"

updated_password="vso-secret-rotated"
vault kv put "${source_path}" \
  username="vso-smoke" \
  password="${updated_password}" \
  source="validate-vault-secrets-operator.sh" >/dev/null
wait_for_secret password "${updated_password}"

cat <<'EOF' | kubectl apply -f - >/dev/null
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: vso-smoke-denied
  namespace: vault-secrets-operator-smoke
spec:
  vaultAuthRef: vso-smoke
  mount: kv
  type: kv-v2
  path: apps/vault-auth-other/dev/demo
  refreshAfter: 15s
  destination:
    name: vso-smoke-denied-secret
    create: true
    overwrite: true
EOF

sleep 10
failure_message="$(kubectl -n "${namespace}" get vaultstaticsecret "${failure_name}" -o jsonpath='{range .status.conditions[*]}{.type}={.status}:{.message}{"\n"}{end}' 2>/dev/null || true)"

kubectl -n "${namespace}" delete vaultstaticsecret "${failure_name}" --ignore-not-found >/dev/null
kubectl -n "${namespace}" delete secret vso-smoke-denied-secret --ignore-not-found >/dev/null

if [[ "${failure_message}" != *"permission denied"* && "${failure_message}" != *"403"* ]]; then
  echo "expected a readable auth/policy failure for ${failure_name}, got:" >&2
  echo "${failure_message:-<no status message>}" >&2
  exit 1
fi

cat <<EOF
vault secrets operator validation passed
  namespace: ${namespace}
  destination secret: ${secret_name}
  source path: ${source_path}
  initial password: ${initial_password}
  updated password: ${updated_password}
  failure probe: ${failure_name}
EOF

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

require_cmd kubectl
require_cmd jq
require_cmd curl

require_env KUBECONFIG

app_name="${ARGO_APP_NAME:-coinvault}"
namespace="${COINVAULT_NAMESPACE:-coinvault}"
host="${COINVAULT_HOST:-coinvault.yolo.scapegoat.dev}"

kubectl get applications.argoproj.io -n argocd "${app_name}" -o json | jq -e '
  .status.sync.status == "Synced" and .status.health.status == "Healthy"
' >/dev/null

kubectl -n "${namespace}" rollout status deployment/coinvault --timeout=180s >/dev/null
kubectl -n "${namespace}" get secret coinvault-runtime coinvault-pinocchio >/dev/null

runtime_keys="$(kubectl -n "${namespace}" get secret coinvault-runtime -o json | jq -r '.data | keys[]' | tr '\n' ' ')"
pinocchio_keys="$(kubectl -n "${namespace}" get secret coinvault-pinocchio -o json | jq -r '.data | keys[]' | tr '\n' ' ')"

curl -fsS "https://${host}/healthz" >/tmp/coinvault-healthz.json
curl -fsSI "https://${host}/auth/login" >/tmp/coinvault-login.headers

grep -qi "302" /tmp/coinvault-login.headers || grep -qi "303" /tmp/coinvault-login.headers

echo "coinvault k3s validation passed"
echo "  argo app: ${app_name}"
echo "  namespace: ${namespace}"
echo "  runtime secret keys: ${runtime_keys}"
echo "  pinocchio secret keys: ${pinocchio_keys}"
echo "  healthz: https://${host}/healthz"
echo "  login redirect: https://${host}/auth/login"

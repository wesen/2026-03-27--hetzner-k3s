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

require_env KUBECONFIG

namespace="${REDIS_NAMESPACE:-redis}"
argo_app="${REDIS_ARGO_APP:-redis}"

kubectl -n argocd get application "${argo_app}" -o json | jq -e '
  .status.sync.status == "Synced" and .status.health.status == "Healthy"
' >/dev/null

kubectl -n "${namespace}" rollout status statefulset/redis --timeout=300s >/dev/null
kubectl -n "${namespace}" get secret redis-auth >/dev/null

redis_password="$(kubectl -n "${namespace}" get secret redis-auth -o jsonpath='{.data.redis-password}' | base64 -d)"
validation_value="redis-$(date +%s)"

kubectl -n "${namespace}" exec statefulset/redis -- env REDISCLI_AUTH="${redis_password}" \
  redis-cli -h 127.0.0.1 SET cluster:persistence "${validation_value}" >/tmp/redis-validate.out

kubectl -n "${namespace}" rollout restart statefulset/redis >/dev/null
kubectl -n "${namespace}" rollout status statefulset/redis --timeout=300s >/dev/null

kubectl -n "${namespace}" exec statefulset/redis -- env REDISCLI_AUTH="${redis_password}" \
  redis-cli -h 127.0.0.1 GET cluster:persistence | grep -qx "${validation_value}"

echo "cluster redis validation passed"
echo "  namespace: ${namespace}"
echo "  argo app: ${argo_app}"
echo "  service: redis.${namespace}.svc.cluster.local:6379"
echo "  validated auth and persistence across restart"

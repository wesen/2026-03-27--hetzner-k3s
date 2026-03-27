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

namespace="${MYSQL_NAMESPACE:-mysql}"
argo_app="${MYSQL_ARGO_APP:-mysql}"

kubectl -n argocd get application "${argo_app}" -o json | jq -e '
  .status.sync.status == "Synced" and .status.health.status == "Healthy"
' >/dev/null

kubectl -n "${namespace}" rollout status statefulset/mysql --timeout=300s >/dev/null
kubectl -n "${namespace}" get secret mysql-auth >/dev/null

root_password="$(kubectl -n "${namespace}" get secret mysql-auth -o jsonpath='{.data.mysql-root-password}' | base64 -d)"

kubectl -n "${namespace}" exec statefulset/mysql -- env MYSQL_PWD="${root_password}" \
  mysql -uroot -h127.0.0.1 -e "SELECT VERSION(); SHOW DATABASES LIKE 'gec'; SELECT User FROM mysql.user WHERE User='coinvault_ro';" >/tmp/mysql-validate.out

echo "cluster mysql validation passed"
echo "  namespace: ${namespace}"
echo "  argo app: ${argo_app}"
echo "  service: mysql.${namespace}.svc.cluster.local:3306"
echo "  validated database: gec"
echo "  validated user: coinvault_ro"

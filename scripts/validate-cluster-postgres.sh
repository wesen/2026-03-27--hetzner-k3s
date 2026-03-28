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

namespace="${POSTGRES_NAMESPACE:-postgres}"
argo_app="${POSTGRES_ARGO_APP:-postgres}"

kubectl -n argocd get application "${argo_app}" -o json | jq -e '
  .status.sync.status == "Synced" and .status.health.status == "Healthy"
' >/dev/null

kubectl -n "${namespace}" rollout status statefulset/postgres --timeout=300s >/dev/null
kubectl -n "${namespace}" get secret postgres-auth >/dev/null

postgres_db="$(kubectl -n "${namespace}" get secret postgres-auth -o jsonpath='{.data.postgres-db}' | base64 -d)"
postgres_user="$(kubectl -n "${namespace}" get secret postgres-auth -o jsonpath='{.data.postgres-user}' | base64 -d)"
postgres_password="$(kubectl -n "${namespace}" get secret postgres-auth -o jsonpath='{.data.postgres-password}' | base64 -d)"

kubectl -n "${namespace}" exec statefulset/postgres -- env PGPASSWORD="${postgres_password}" \
  psql -U "${postgres_user}" -d "${postgres_db}" -h 127.0.0.1 -v ON_ERROR_STOP=1 \
  -c "CREATE TABLE IF NOT EXISTS platform_validation (id text primary key, touched_at timestamptz not null default now());" \
  -c "INSERT INTO platform_validation (id) VALUES ('postgres-persistence') ON CONFLICT (id) DO UPDATE SET touched_at = now();" \
  -c "SELECT version();" >/tmp/postgres-validate.out

kubectl -n "${namespace}" rollout restart statefulset/postgres >/dev/null
kubectl -n "${namespace}" rollout status statefulset/postgres --timeout=300s >/dev/null

kubectl -n "${namespace}" exec statefulset/postgres -- env PGPASSWORD="${postgres_password}" \
  psql -U "${postgres_user}" -d "${postgres_db}" -h 127.0.0.1 -tAc \
  "SELECT count(*) FROM platform_validation WHERE id = 'postgres-persistence';" | grep -qx '1'

echo "cluster postgres validation passed"
echo "  namespace: ${namespace}"
echo "  argo app: ${argo_app}"
echo "  service: postgres.${namespace}.svc.cluster.local:5432"
echo "  validated database: ${postgres_db}"
echo "  validated user: ${postgres_user}"
echo "  validated persistence across restart"

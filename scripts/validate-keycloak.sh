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

namespace="${KEYCLOAK_NAMESPACE:-keycloak}"
argo_app="${KEYCLOAK_ARGO_APP:-keycloak}"
public_host="${KEYCLOAK_PUBLIC_HOST:-https://auth.yolo.scapegoat.dev}"

kubectl -n argocd get application "${argo_app}" -o json | jq -e '
  .status.sync.status == "Synced" and .status.health.status == "Healthy"
' >/dev/null

kubectl -n "${namespace}" rollout status deployment/keycloak --timeout=600s >/dev/null
kubectl -n "${namespace}" get secret keycloak-runtime >/dev/null
kubectl -n "${namespace}" get secret keycloak-bootstrap-admin >/dev/null
kubectl -n "${namespace}" get secret keycloak-postgres-admin >/dev/null

postgres_user="$(kubectl -n "${namespace}" get secret keycloak-postgres-admin -o jsonpath='{.data.postgres-user}' | base64 -d)"
postgres_password="$(kubectl -n "${namespace}" get secret keycloak-postgres-admin -o jsonpath='{.data.postgres-password}' | base64 -d)"

kubectl -n postgres exec statefulset/postgres -- env PGPASSWORD="${postgres_password}" \
  psql -U "${postgres_user}" -d postgres -h 127.0.0.1 -tAc \
  "SELECT datname FROM pg_database WHERE datname = 'keycloak';" | grep -qx 'keycloak'

kubectl -n postgres exec statefulset/postgres -- env PGPASSWORD="${postgres_password}" \
  psql -U "${postgres_user}" -d postgres -h 127.0.0.1 -tAc \
  "SELECT rolname FROM pg_roles WHERE rolname = 'keycloak_app';" | grep -qx 'keycloak_app'

bootstrap_user="$(kubectl -n "${namespace}" get secret keycloak-bootstrap-admin -o jsonpath='{.data.username}' | base64 -d)"
bootstrap_password="$(kubectl -n "${namespace}" get secret keycloak-bootstrap-admin -o jsonpath='{.data.password}' | base64 -d)"

token_endpoint="$(curl -fsS "${public_host}/realms/master/.well-known/openid-configuration" | jq -r '.token_endpoint')"

curl -fsS \
  -X POST \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'client_id=admin-cli' \
  --data-urlencode 'grant_type=password' \
  --data-urlencode "username=${bootstrap_user}" \
  --data-urlencode "password=${bootstrap_password}" \
  "${token_endpoint}" | jq -e -r '.access_token' >/dev/null

echo "keycloak validation passed"
echo "  namespace: ${namespace}"
echo "  argo app: ${argo_app}"
echo "  public host: ${public_host}"
echo "  validated database: keycloak"
echo "  validated role: keycloak_app"
echo "  validated bootstrap-admin login against the public hostname"

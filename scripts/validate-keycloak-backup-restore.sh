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
require_cmd mktemp

require_env KUBECONFIG

keycloak_namespace="${KEYCLOAK_NAMESPACE:-keycloak}"
postgres_namespace="${POSTGRES_NAMESPACE:-postgres}"
postgres_pod="${POSTGRES_POD:-postgres-0}"
source_db="${KEYCLOAK_SOURCE_DB:-keycloak}"
scratch_db="${KEYCLOAK_SCRATCH_DB:-keycloak_restore_smoke}"
expected_realm="${KEYCLOAK_EXPECTED_REALM:-infra}"
expected_client="${KEYCLOAK_EXPECTED_CLIENT:-vault-oidc}"

postgres_user="$(kubectl -n "${keycloak_namespace}" get secret keycloak-postgres-admin -o jsonpath='{.data.postgres-user}' | base64 -d)"
postgres_password="$(kubectl -n "${keycloak_namespace}" get secret keycloak-postgres-admin -o jsonpath='{.data.postgres-password}' | base64 -d)"
postgres_host="$(kubectl -n "${keycloak_namespace}" get secret keycloak-postgres-admin -o jsonpath='{.data.service-host}' | base64 -d)"
postgres_port="$(kubectl -n "${keycloak_namespace}" get secret keycloak-postgres-admin -o jsonpath='{.data.service-port}' | base64 -d)"

dump_file="$(mktemp)"
cleanup() {
  rm -f "${dump_file}"
  kubectl -n "${postgres_namespace}" exec "${postgres_pod}" -- env PGPASSWORD="${postgres_password}" \
    psql -h "${postgres_host}" -p "${postgres_port}" -U "${postgres_user}" -d postgres -v ON_ERROR_STOP=1 \
    -c "DROP DATABASE IF EXISTS ${scratch_db};" >/dev/null 2>&1 || true
}
trap cleanup EXIT

kubectl -n "${postgres_namespace}" exec "${postgres_pod}" -- env PGPASSWORD="${postgres_password}" \
  psql -h "${postgres_host}" -p "${postgres_port}" -U "${postgres_user}" -d postgres -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS ${scratch_db};" \
  -c "CREATE DATABASE ${scratch_db};" >/dev/null

kubectl -n "${postgres_namespace}" exec "${postgres_pod}" -- env PGPASSWORD="${postgres_password}" \
  pg_dump -h "${postgres_host}" -p "${postgres_port}" -U "${postgres_user}" -d "${source_db}" \
  --clean --if-exists --no-owner --no-privileges >"${dump_file}"

kubectl -n "${postgres_namespace}" exec -i "${postgres_pod}" -- env PGPASSWORD="${postgres_password}" \
  psql -h "${postgres_host}" -p "${postgres_port}" -U "${postgres_user}" -d "${scratch_db}" -v ON_ERROR_STOP=1 \
  <"${dump_file}" >/dev/null

realm_count="$(kubectl -n "${postgres_namespace}" exec "${postgres_pod}" -- env PGPASSWORD="${postgres_password}" \
  psql -h "${postgres_host}" -p "${postgres_port}" -U "${postgres_user}" -d "${scratch_db}" -tAc \
  "SELECT COUNT(*) FROM realm WHERE name = '${expected_realm}';")"

client_count="$(kubectl -n "${postgres_namespace}" exec "${postgres_pod}" -- env PGPASSWORD="${postgres_password}" \
  psql -h "${postgres_host}" -p "${postgres_port}" -U "${postgres_user}" -d "${scratch_db}" -tAc \
  "SELECT COUNT(*) FROM client WHERE client_id = '${expected_client}';")"

[[ "${realm_count}" == "1" ]] || {
  echo "expected restored realm ${expected_realm}, got count=${realm_count}" >&2
  exit 1
}

[[ "${client_count}" == "1" ]] || {
  echo "expected restored client ${expected_client}, got count=${client_count}" >&2
  exit 1
}

echo "keycloak backup/restore validation passed"
echo "  source database: ${source_db}"
echo "  scratch database: ${scratch_db}"
echo "  verified realm: ${expected_realm}"
echo "  verified client: ${expected_client}"

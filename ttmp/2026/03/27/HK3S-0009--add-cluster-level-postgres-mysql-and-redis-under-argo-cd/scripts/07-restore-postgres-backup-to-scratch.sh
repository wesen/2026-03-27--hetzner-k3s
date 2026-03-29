#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-common.sh"

require_cmd kubectl
require_cmd gzip
setup_kubeconfig
load_backup_storage_env

namespace="${POSTGRES_NAMESPACE:-postgres}"
object_key="${1:-$(latest_backup_object_key "postgres/")}"
[[ -n "${object_key}" ]] || {
  printf 'no postgres backup object found\n' >&2
  exit 1
}

workdir="$(mktemp -d)"
pod_name="postgres-restore-$(date -u +%Y%m%d%H%M%S)"
local_archive="${workdir}/postgres.sql.gz"

cleanup() {
  kubectl -n "${namespace}" delete pod "${pod_name}" --ignore-not-found >/dev/null 2>&1 || true
  rm -rf "${workdir}"
}
trap cleanup EXIT

aws --endpoint-url "${BACKUP_STORAGE_ENDPOINT_URL}" s3 cp "s3://${BACKUP_STORAGE_BUCKET_NAME}/${object_key}" "${local_archive}" >/dev/null

kubectl -n "${namespace}" run "${pod_name}" --image=postgres:16-alpine --restart=Never --command -- sh -c 'sleep 3600' >/dev/null
kubectl -n "${namespace}" wait --for=condition=Ready --timeout=120s "pod/${pod_name}" >/dev/null
kubectl -n "${namespace}" cp "${local_archive}" "${pod_name}:/tmp/postgres.sql.gz" >/dev/null

kubectl -n "${namespace}" exec "${pod_name}" -- sh -lc '
  set -euo pipefail
  mkdir -p /tmp/pgdata
  chown -R postgres:postgres /tmp/pgdata
  su postgres -c "initdb -D /tmp/pgdata" >/dev/null
  su postgres -c "pg_ctl -D /tmp/pgdata -o '\''-c listen_addresses=127.0.0.1 -c unix_socket_directories=/tmp'\'' -w start" >/dev/null
  gunzip -c /tmp/postgres.sql.gz | psql -h 127.0.0.1 -U postgres postgres >/tmp/postgres-restore.log
  printf "databases:\n"
  psql -h 127.0.0.1 -U postgres -Atc "select datname from pg_database where datistemplate = false order by datname"
  printf "draft_review_users=%s\n" "$(psql -h 127.0.0.1 -U postgres -d draft_review -Atc "select count(*) from users")"
  su postgres -c "pg_ctl -D /tmp/pgdata -m fast stop" >/dev/null
'

log "restored ${object_key} into scratch pod ${pod_name}"

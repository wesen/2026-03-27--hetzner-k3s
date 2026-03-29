#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-common.sh"

require_cmd kubectl
setup_kubeconfig
load_backup_storage_env

namespace="${MYSQL_NAMESPACE:-mysql}"
object_key="${1:-$(latest_backup_object_key "mysql/")}"
[[ -n "${object_key}" ]] || {
  printf 'no mysql backup object found\n' >&2
  exit 1
}

workdir="$(mktemp -d)"
pod_name="mysql-restore-$(date -u +%Y%m%d%H%M%S)"
local_archive="${workdir}/mysql.sql.gz"

cleanup() {
  kubectl -n "${namespace}" delete pod "${pod_name}" --ignore-not-found >/dev/null 2>&1 || true
  rm -rf "${workdir}"
}
trap cleanup EXIT

aws --endpoint-url "${BACKUP_STORAGE_ENDPOINT_URL}" s3 cp "s3://${BACKUP_STORAGE_BUCKET_NAME}/${object_key}" "${local_archive}" >/dev/null

kubectl -n "${namespace}" run "${pod_name}" --image=mysql:8.4 --restart=Never --command -- bash -lc 'sleep 3600' >/dev/null
kubectl -n "${namespace}" wait --for=condition=Ready --timeout=120s "pod/${pod_name}" >/dev/null
kubectl -n "${namespace}" cp "${local_archive}" "${pod_name}:/tmp/mysql.sql.gz" >/dev/null

kubectl -n "${namespace}" exec "${pod_name}" -- bash -lc '
  set -euo pipefail
  rm -rf /tmp/mysql-data
  mkdir -p /tmp/mysql-data
  chown -R mysql:mysql /tmp/mysql-data
  mysqld --initialize-insecure --user=mysql --datadir=/tmp/mysql-data >/tmp/mysql-init.log 2>&1
  mysqld --user=mysql --datadir=/tmp/mysql-data --socket=/tmp/mysql.sock --pid-file=/tmp/mysql.pid --port=3307 --bind-address=127.0.0.1 --innodb-redo-log-capacity=1073741824 >/tmp/mysql.log 2>&1 &
  for _ in $(seq 1 60); do
    if mysqladmin --protocol=socket --socket=/tmp/mysql.sock -uroot ping >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  gunzip -c /tmp/mysql.sql.gz | mysql --protocol=socket --socket=/tmp/mysql.sock -uroot
  printf "databases:\n"
  mysql --protocol=socket --socket=/tmp/mysql.sock -uroot -Nse "show databases"
  printf "gec_products=%s\n" "$(mysql --protocol=socket --socket=/tmp/mysql.sock -uroot -Nse "select count(*) from gec.products")"
  mysqladmin --protocol=socket --socket=/tmp/mysql.sock -uroot shutdown >/dev/null
'

log "restored ${object_key} into scratch pod ${pod_name}"

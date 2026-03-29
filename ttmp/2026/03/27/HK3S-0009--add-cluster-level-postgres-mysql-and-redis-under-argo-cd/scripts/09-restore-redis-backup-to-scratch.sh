#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-common.sh"

require_cmd kubectl
setup_kubeconfig
load_backup_storage_env

namespace="${REDIS_NAMESPACE:-redis}"
object_key="${1:-$(latest_backup_object_key "redis/")}"
[[ -n "${object_key}" ]] || {
  printf 'no redis backup object found\n' >&2
  exit 1
}

workdir="$(mktemp -d)"
pod_name="redis-restore-$(date -u +%Y%m%d%H%M%S)"
local_archive="${workdir}/redis.tar.gz"

cleanup() {
  kubectl -n "${namespace}" delete pod "${pod_name}" --ignore-not-found >/dev/null 2>&1 || true
  rm -rf "${workdir}"
}
trap cleanup EXIT

aws --endpoint-url "${BACKUP_STORAGE_ENDPOINT_URL}" s3 cp "s3://${BACKUP_STORAGE_BUCKET_NAME}/${object_key}" "${local_archive}" >/dev/null

kubectl -n "${namespace}" run "${pod_name}" --image=redis:7-alpine --restart=Never --command -- sh -c 'sleep 3600' >/dev/null
kubectl -n "${namespace}" wait --for=condition=Ready --timeout=120s "pod/${pod_name}" >/dev/null
kubectl -n "${namespace}" cp "${local_archive}" "${pod_name}:/tmp/redis.tar.gz" >/dev/null

kubectl -n "${namespace}" exec "${pod_name}" -- sh -lc '
  set -eu
  mkdir -p /data /tmp/restore
  tar -xzf /tmp/redis.tar.gz -C /tmp/restore
  restore_rdb="$(find /tmp/restore -name "*.rdb" | head -n 1)"
  if [ -z "${restore_rdb}" ]; then
    printf "no rdb file found in redis backup archive\n" >&2
    exit 1
  fi
  cp "${restore_rdb}" /data/dump.rdb
  redis-server --dir /data --dbfilename dump.rdb --appendonly no --port 6380 --bind 127.0.0.1 --protected-mode no >/tmp/redis.log 2>&1 &
  ready=0
  for _ in $(seq 1 60); do
    if redis-cli -p 6380 ping >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 1
  done
  if [ "${ready}" -ne 1 ]; then
    cat /tmp/redis.log >&2
    exit 1
  fi
  printf "dbsize=%s\n" "$(redis-cli -p 6380 DBSIZE)"
  printf "cluster_persistence=%s\n" "$(redis-cli -p 6380 GET cluster:persistence)"
  redis-cli -p 6380 shutdown nosave >/dev/null
'

log "restored ${object_key} into scratch pod ${pod_name}"

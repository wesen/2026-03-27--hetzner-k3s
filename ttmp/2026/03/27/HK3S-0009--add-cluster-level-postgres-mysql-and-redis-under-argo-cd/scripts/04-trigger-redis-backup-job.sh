#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-common.sh"

require_cmd kubectl
setup_kubeconfig

job_name="redis-backup-manual-$(date -u +%Y%m%d%H%M%S)"

kubectl -n redis delete job "${job_name}" --ignore-not-found >/dev/null
kubectl -n redis create job --from=cronjob/redis-backup "${job_name}" >/dev/null
kubectl -n redis wait --for=condition=complete --timeout=10m "job/${job_name}" >/dev/null
kubectl -n redis logs "job/${job_name}"

log "completed ${job_name}"


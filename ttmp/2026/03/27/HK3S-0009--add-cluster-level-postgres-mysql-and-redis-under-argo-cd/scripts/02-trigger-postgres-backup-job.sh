#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-common.sh"

require_cmd kubectl
setup_kubeconfig

job_name="postgres-backup-manual-$(date -u +%Y%m%d%H%M%S)"

kubectl -n postgres delete job "${job_name}" --ignore-not-found >/dev/null
kubectl -n postgres create job --from=cronjob/postgres-backup "${job_name}" >/dev/null
kubectl -n postgres wait --for=condition=complete --timeout=10m "job/${job_name}" >/dev/null
kubectl -n postgres logs "job/${job_name}"

log "completed ${job_name}"


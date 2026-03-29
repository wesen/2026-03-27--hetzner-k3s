#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-common.sh"

require_cmd kubectl
setup_kubeconfig

job_name="mysql-backup-manual-$(date -u +%Y%m%d%H%M%S)"

kubectl -n mysql delete job "${job_name}" --ignore-not-found >/dev/null
kubectl -n mysql create job --from=cronjob/mysql-backup "${job_name}" >/dev/null
kubectl -n mysql wait --for=condition=complete --timeout=10m "job/${job_name}" >/dev/null
kubectl -n mysql logs "job/${job_name}"

log "completed ${job_name}"


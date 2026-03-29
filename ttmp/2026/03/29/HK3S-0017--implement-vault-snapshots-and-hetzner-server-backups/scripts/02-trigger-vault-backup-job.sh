#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-common.sh"

require_cmd kubectl
setup_kubeconfig

namespace="${VAULT_NAMESPACE:-vault}"
cronjob="${VAULT_BACKUP_CRONJOB_NAME:-vault-backup}"
job_name="${cronjob}-manual-$(date -u +%Y%m%d%H%M%S)"

kubectl -n "${namespace}" create job --from=cronjob/"${cronjob}" "${job_name}" >/dev/null
kubectl -n "${namespace}" wait --for=condition=complete --timeout=300s "job/${job_name}" >/dev/null
kubectl -n "${namespace}" logs "job/${job_name}"

log "triggered ${job_name}"

#!/usr/bin/env bash

set -euo pipefail

namespace="${VAULT_NAMESPACE:-vault}"
secret_name="${VAULT_AWS_SECRET_NAME:-vault-aws-kms}"
aws_profile="${AWS_PROFILE:-}"

require() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "missing required environment variable: ${name}" >&2
    exit 1
  fi
}

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required" >&2
  exit 1
fi

if [[ -n "${aws_profile}" ]]; then
  : "${AWS_ACCESS_KEY_ID:=$(aws configure get aws_access_key_id --profile "${aws_profile}")}"
  : "${AWS_SECRET_ACCESS_KEY:=$(aws configure get aws_secret_access_key --profile "${aws_profile}")}"
  : "${AWS_REGION:=$(aws configure get region --profile "${aws_profile}")}"
fi

require AWS_ACCESS_KEY_ID
require AWS_SECRET_ACCESS_KEY
require AWS_REGION

kubectl get namespace "${namespace}" >/dev/null 2>&1 || kubectl create namespace "${namespace}"

kubectl create secret generic "${secret_name}" \
  --namespace "${namespace}" \
  --from-literal=AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
  --from-literal=AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
  --from-literal=AWS_REGION="${AWS_REGION}" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

echo "vault aws kms secret applied: namespace=${namespace} secret=${secret_name}"

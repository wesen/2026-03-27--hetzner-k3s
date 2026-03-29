#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-common.sh"

require_cmd vault
require_cmd jq
require_cmd aws
require_env VAULT_ADDR
require_env VAULT_TOKEN

payload="$(vault_kv_get_json "infra/backups/object-storage")"
bucket_name="$(jq -r '."bucket-name"' <<<"${payload}")"
storage_endpoint="$(jq -r '."storage-endpoint"' <<<"${payload}")"
storage_region="$(jq -r '."storage-region"' <<<"${payload}")"
access_key="$(jq -r '."access-key"' <<<"${payload}")"
secret_key="$(jq -r '."secret-key"' <<<"${payload}")"

AWS_ACCESS_KEY_ID="${access_key}" \
AWS_SECRET_ACCESS_KEY="${secret_key}" \
AWS_DEFAULT_REGION="${storage_region}" \
  aws --endpoint-url "${storage_endpoint}" s3 ls "s3://${bucket_name}" --recursive


#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-common.sh"

require_cmd terraform
require_cmd vault
require_cmd jq
require_env VAULT_ADDR
require_env VAULT_TOKEN

terraform_env_dir="${TERRAFORM_BACKUP_ENV_DIR:-/home/manuel/code/wesen/terraform/storage/platform/k3s-backups/envs/prod}"
secret_path="${BACKUP_STORAGE_SECRET_PATH:-infra/backups/object-storage}"

if [[ -z "${TF_VAR_object_storage_access_key:-}" || -z "${TF_VAR_object_storage_secret_key:-}" || -z "${TF_VAR_object_storage_server:-}" ]]; then
  if command -v direnv >/dev/null 2>&1; then
    eval "$(
      direnv exec "${terraform_env_dir}" bash -lc \
        'printf "export TF_VAR_object_storage_access_key=%q\n" "$TF_VAR_object_storage_access_key"; printf "export TF_VAR_object_storage_secret_key=%q\n" "$TF_VAR_object_storage_secret_key"; printf "export TF_VAR_object_storage_server=%q\n" "$TF_VAR_object_storage_server"; printf "export TF_VAR_object_storage_region=%q\n" "$TF_VAR_object_storage_region"'
    )"
  fi
fi

require_env TF_VAR_object_storage_access_key
require_env TF_VAR_object_storage_secret_key
require_env TF_VAR_object_storage_server

bucket_name="${BACKUP_STORAGE_BUCKET_NAME:-scapegoat-k3s-backups}"
storage_endpoint_url="${BACKUP_STORAGE_ENDPOINT_URL:-https://${TF_VAR_object_storage_server}}"
storage_region="${TF_VAR_object_storage_region:-fsn1}"

if [[ "${USE_TERRAFORM_OUTPUTS:-false}" == "true" ]]; then
  bucket_name="$(terraform -chdir="${terraform_env_dir}" output -raw bucket_name)"
  storage_endpoint_url="$(terraform -chdir="${terraform_env_dir}" output -raw storage_endpoint_url)"
  storage_region="$(terraform -chdir="${terraform_env_dir}" output -raw storage_region)"
fi

VAULT_ADDR="${VAULT_ADDR}" VAULT_TOKEN="${VAULT_TOKEN}" \
  vault kv put "kv/${secret_path}" \
    storage-endpoint="${storage_endpoint_url}" \
    storage-region="${storage_region}" \
    bucket-name="${bucket_name}" \
    access-key="${TF_VAR_object_storage_access_key}" \
    secret-key="${TF_VAR_object_storage_secret_key}" \
    postgres-prefix="postgres/" \
    mysql-prefix="mysql/" \
    redis-prefix="redis/" >/dev/null

log "seeded kv/${secret_path}"
log "bucket=${bucket_name} endpoint=${storage_endpoint_url} region=${storage_region}"
log "no secret values were printed"

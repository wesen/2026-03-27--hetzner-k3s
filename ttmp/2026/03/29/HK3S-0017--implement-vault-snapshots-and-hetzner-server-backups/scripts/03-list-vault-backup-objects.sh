#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-common.sh"

require_cmd aws
require_env VAULT_ADDR
load_vault_token_if_needed
load_backup_storage_env

aws --endpoint-url "${BACKUP_STORAGE_ENDPOINT_URL}" s3 ls "s3://${BACKUP_STORAGE_BUCKET_NAME}/vault/" --recursive

#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/00-common.sh"

require_cmd vault
require_env VAULT_ADDR
load_vault_token_if_needed
require_env VAULT_TOKEN

"${REPO_ROOT}/scripts/bootstrap-vault-kubernetes-auth.sh"

log "bootstrapped Vault Kubernetes auth policies and roles, including vault-backup"

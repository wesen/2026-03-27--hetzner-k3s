#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
POLICY_DIR="${ROOT_DIR}/vault/policies/operators"

VAULT_ADDR="${VAULT_ADDR:-https://vault.yolo.scapegoat.dev}"
VAULT_OIDC_PATH="${VAULT_OIDC_PATH:-oidc}"
VAULT_OIDC_DISCOVERY_URL="${VAULT_OIDC_DISCOVERY_URL:-https://auth.scapegoat.dev/realms/infra}"
VAULT_OIDC_CLIENT_ID="${VAULT_OIDC_CLIENT_ID:-vault-oidc}"
VAULT_OIDC_DEFAULT_ROLE="${VAULT_OIDC_DEFAULT_ROLE:-operators}"
VAULT_ADMIN_GROUP_NAME="${VAULT_ADMIN_GROUP_NAME:-infra-admins}"
VAULT_READONLY_GROUP_NAME="${VAULT_READONLY_GROUP_NAME:-infra-readonly}"
VAULT_UI_REDIRECT_URI="${VAULT_UI_REDIRECT_URI:-https://vault.yolo.scapegoat.dev/ui/vault/auth/oidc/oidc/callback}"
VAULT_LOCALHOST_REDIRECT_URI="${VAULT_LOCALHOST_REDIRECT_URI:-http://localhost:8250/oidc/callback}"
VAULT_LOOPBACK_REDIRECT_URI="${VAULT_LOOPBACK_REDIRECT_URI:-http://127.0.0.1:8250/oidc/callback}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "missing required environment variable: ${name}" >&2
    exit 1
  fi
}

ensure_auth_backend() {
  local mount_path="$1"
  local auth_type="$2"
  local auth_json
  local mount_key="${mount_path}/"
  local existing_type

  auth_json="$(vault auth list -format=json)"
  if jq -e --arg key "${mount_key}" 'has($key)' <<<"${auth_json}" >/dev/null; then
    existing_type="$(jq -r --arg key "${mount_key}" '.[$key].type' <<<"${auth_json}")"
    if [[ "${existing_type}" != "${auth_type}" ]]; then
      echo "auth backend ${mount_key} already exists with type ${existing_type}, expected ${auth_type}" >&2
      exit 1
    fi
    return
  fi

  vault auth enable -path="${mount_path}" "${auth_type}" >/dev/null
}

write_policy() {
  local name="$1"
  local path="$2"
  vault policy write "${name}" "${path}" >/dev/null
}

upsert_external_group() {
  local name="$1"
  local policies="$2"
  local existing_json
  local group_id

  existing_json="$(vault read -format=json "identity/group/name/${name}" 2>/dev/null || true)"
  if [[ -n "${existing_json}" ]]; then
    group_id="$(jq -r '.data.id // empty' <<<"${existing_json}")"
  else
    group_id=""
  fi

  if [[ -n "${group_id}" ]]; then
    vault write identity/group id="${group_id}" name="${name}" type="external" policies="${policies}" >/dev/null
  else
    group_id="$(vault write -format=json identity/group name="${name}" type="external" policies="${policies}" | jq -r '.data.id')"
  fi

  printf '%s\n' "${group_id}"
}

upsert_group_alias() {
  local alias_name="$1"
  local mount_accessor="$2"
  local canonical_id="$3"
  local lookup_json
  local alias_id

  lookup_json="$(vault write -format=json identity/lookup/group alias_name="${alias_name}" alias_mount_accessor="${mount_accessor}" 2>/dev/null || true)"
  alias_id="$(jq -r '.data.alias.id // empty' <<<"${lookup_json}" 2>/dev/null || true)"

  if [[ -n "${alias_id}" ]]; then
    vault write "identity/group-alias/id/${alias_id}" name="${alias_name}" mount_accessor="${mount_accessor}" canonical_id="${canonical_id}" >/dev/null
  else
    vault write identity/group-alias name="${alias_name}" mount_accessor="${mount_accessor}" canonical_id="${canonical_id}" >/dev/null
  fi
}

require_cmd vault
require_cmd jq
require_cmd curl
require_env VAULT_TOKEN
require_env VAULT_OIDC_CLIENT_SECRET

export VAULT_ADDR

ensure_auth_backend "${VAULT_OIDC_PATH}" "oidc"

vault write "auth/${VAULT_OIDC_PATH}/config" \
  oidc_discovery_url="${VAULT_OIDC_DISCOVERY_URL}" \
  oidc_client_id="${VAULT_OIDC_CLIENT_ID}" \
  oidc_client_secret="${VAULT_OIDC_CLIENT_SECRET}" \
  default_role="${VAULT_OIDC_DEFAULT_ROLE}" >/dev/null

oidc_role_payload="$(jq -nc \
  --arg user_claim "preferred_username" \
  --arg groups_claim "groups" \
  --arg admin "${VAULT_ADMIN_GROUP_NAME}" \
  --arg readonly "${VAULT_READONLY_GROUP_NAME}" \
  --arg redirect_localhost "${VAULT_LOCALHOST_REDIRECT_URI}" \
  --arg redirect_loopback "${VAULT_LOOPBACK_REDIRECT_URI}" \
  --arg redirect_ui "${VAULT_UI_REDIRECT_URI}" \
  '{
    role_type: "oidc",
    user_claim: $user_claim,
    groups_claim: $groups_claim,
    bound_claims: {
      groups: [$admin, $readonly]
    },
    allowed_redirect_uris: [
      $redirect_localhost,
      $redirect_loopback,
      $redirect_ui
    ],
    oidc_scopes: ["openid", "profile", "email"]
  }'
)"

curl -fsS \
  -X POST \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "${oidc_role_payload}" \
  "${VAULT_ADDR}/v1/auth/${VAULT_OIDC_PATH}/role/${VAULT_OIDC_DEFAULT_ROLE}" >/dev/null

write_policy "admin" "${POLICY_DIR}/admin.hcl"
write_policy "ops-readonly" "${POLICY_DIR}/ops-readonly.hcl"

oidc_accessor="$(vault auth list -format=json | jq -r --arg key "${VAULT_OIDC_PATH}/" '.[$key].accessor')"
admin_group_id="$(upsert_external_group "${VAULT_ADMIN_GROUP_NAME}" "admin")"
readonly_group_id="$(upsert_external_group "${VAULT_READONLY_GROUP_NAME}" "ops-readonly")"

upsert_group_alias "${VAULT_ADMIN_GROUP_NAME}" "${oidc_accessor}" "${admin_group_id}"
upsert_group_alias "${VAULT_READONLY_GROUP_NAME}" "${oidc_accessor}" "${readonly_group_id}"

cat <<EOF
Configured Vault operator OIDC:
- auth path: ${VAULT_OIDC_PATH}/
- discovery URL: ${VAULT_OIDC_DISCOVERY_URL}
- client ID: ${VAULT_OIDC_CLIENT_ID}
- default role: ${VAULT_OIDC_DEFAULT_ROLE}
- UI redirect URI: ${VAULT_UI_REDIRECT_URI}
- CLI redirect URIs:
  - ${VAULT_LOCALHOST_REDIRECT_URI}
  - ${VAULT_LOOPBACK_REDIRECT_URI}
- admin group alias: ${VAULT_ADMIN_GROUP_NAME}
- readonly group alias: ${VAULT_READONLY_GROUP_NAME}
EOF

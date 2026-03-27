#!/usr/bin/env bash
set -euo pipefail

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

require_cmd vault
require_cmd jq
require_cmd curl
require_env VAULT_TOKEN

export VAULT_ADDR

auth_json="$(vault auth list -format=json)"
jq -e --arg key "${VAULT_OIDC_PATH}/" 'has($key)' <<<"${auth_json}" >/dev/null

role_json="$(vault read -format=json "auth/${VAULT_OIDC_PATH}/role/${VAULT_OIDC_DEFAULT_ROLE}")"
jq -e --arg ui "${VAULT_UI_REDIRECT_URI}" --arg lh "${VAULT_LOCALHOST_REDIRECT_URI}" --arg lb "${VAULT_LOOPBACK_REDIRECT_URI}" '
  .data.user_claim == "preferred_username" and
  .data.groups_claim == "groups" and
  .data.role_type == "oidc" and
  (.data.allowed_redirect_uris | index($ui)) != null and
  (.data.allowed_redirect_uris | index($lh)) != null and
  (.data.allowed_redirect_uris | index($lb)) != null
' <<<"${role_json}" >/dev/null

for policy in admin ops-readonly; do
  vault policy read "${policy}" >/dev/null
done

oidc_accessor="$(jq -r --arg key "${VAULT_OIDC_PATH}/" '.[$key].accessor' <<<"${auth_json}")"
for group_name in "${VAULT_ADMIN_GROUP_NAME}" "${VAULT_READONLY_GROUP_NAME}"; do
  vault read "identity/group/name/${group_name}" >/dev/null
  vault write -format=json identity/lookup/group alias_name="${group_name}" alias_mount_accessor="${oidc_accessor}" | jq -e '.data.id != null and .data.alias.id != null' >/dev/null
done

auth_page="$(curl -fsSLG \
  --data-urlencode "client_id=${VAULT_OIDC_CLIENT_ID}" \
  --data-urlencode "redirect_uri=${VAULT_UI_REDIRECT_URI}" \
  --data-urlencode "response_type=code" \
  --data-urlencode "scope=openid profile email" \
  "${VAULT_OIDC_DISCOVERY_URL}/protocol/openid-connect/auth")"

if grep -q "Invalid parameter: redirect_uri" <<<"${auth_page}"; then
  echo "keycloak rejected the Vault UI redirect URI" >&2
  exit 1
fi

cat <<EOF
Vault OIDC config validation passed:
- auth path: ${VAULT_OIDC_PATH}/
- default role: ${VAULT_OIDC_DEFAULT_ROLE}
- UI redirect URI accepted by Keycloak: ${VAULT_UI_REDIRECT_URI}
- CLI redirect URIs present:
  - ${VAULT_LOCALHOST_REDIRECT_URI}
  - ${VAULT_LOOPBACK_REDIRECT_URI}
- external group aliases:
  - ${VAULT_ADMIN_GROUP_NAME}
  - ${VAULT_READONLY_GROUP_NAME}
EOF

#!/usr/bin/env bash

set -euo pipefail

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || {
    echo "missing required environment variable: $name" >&2
    exit 1
  }
}

require_cmd vault
require_cmd python3
require_cmd base64

require_env VAULT_ADDR
require_env VAULT_TOKEN
require_env GITHUB_DEPLOY_PAT

repo_root="/home/manuel/code/wesen/2026-03-27--hetzner-k3s"
tfvars_path="/home/manuel/code/wesen/terraform/keycloak/apps/draft-review/envs/k3s-parallel/terraform.tfvars"

oidc_client_secret="$(python3 - <<'PY'
from pathlib import Path
path = Path("/home/manuel/code/wesen/terraform/keycloak/apps/draft-review/envs/k3s-parallel/terraform.tfvars")
for line in path.read_text().splitlines():
    line = line.strip()
    if not line.startswith("web_client_secret"):
        continue
    print(line.split("=", 1)[1].strip().strip('"'))
    break
PY
)"

db_password="$(openssl rand -base64 32 | tr -d '\n')"
session_secret="$(openssl rand -base64 32 | tr -d '\n')"
ghcr_auth="$(printf '%s:%s' "wesen" "${GITHUB_DEPLOY_PAT}" | base64 | tr -d '\n')"

vault kv put kv/apps/draft-review/prod/runtime \
  service_host="postgres.postgres.svc.cluster.local" \
  service_port="5432" \
  database="draft_review" \
  username="draft_review" \
  password="${db_password}" \
  dsn="postgres://draft_review:${db_password}@postgres.postgres.svc.cluster.local:5432/draft_review?sslmode=disable" \
  session_secret="${session_secret}" \
  oidc_issuer_url="https://auth.yolo.scapegoat.dev/realms/draft-review" \
  oidc_redirect_url="https://draft-review.yolo.scapegoat.dev/auth/callback" \
  oidc_client_secret="${oidc_client_secret}" >/dev/null

vault kv put kv/apps/draft-review/prod/image-pull \
  server="ghcr.io" \
  username="wesen" \
  password="${GITHUB_DEPLOY_PAT}" \
  auth="${ghcr_auth}" >/dev/null

echo "seeded kv/apps/draft-review/prod/runtime"
echo "seeded kv/apps/draft-review/prod/image-pull"

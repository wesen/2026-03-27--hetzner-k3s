#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./00-common.sh
source "$SCRIPT_DIR/00-common.sh"

require_cmd kubectl
require_cmd terraform

NEW_SUBJECT="${1:-$(terraform_wesen_subject)}"
ADMIN_USER="$(cluster_admin_user)"
ADMIN_PASSWORD="$(cluster_admin_password)"
SERVICE_HOST="$(cluster_service_host)"
SERVICE_PORT="$(cluster_service_port)"

ROW_COUNT="$(kubectl -n "$CLUSTER_POSTGRES_NAMESPACE" exec "$CLUSTER_POSTGRES_STATEFULSET-0" -- sh -lc \
  "export PGPASSWORD='$ADMIN_PASSWORD'; psql \
    -v ON_ERROR_STOP=1 \
    -h '$SERVICE_HOST' \
    -p '$SERVICE_PORT' \
    -U '$ADMIN_USER' \
    -d '$CLUSTER_DATABASE' \
    -At -c \"select count(*) from public.users where email = '$WESEN_EMAIL'\"")"

if [[ "$ROW_COUNT" != "1" ]]; then
  echo "expected exactly one $WESEN_EMAIL row before rewrite, got $ROW_COUNT" >&2
  exit 1
fi

kubectl -n "$CLUSTER_POSTGRES_NAMESPACE" exec "$CLUSTER_POSTGRES_STATEFULSET-0" -- sh -lc \
  "export PGPASSWORD='$ADMIN_PASSWORD'; psql \
    -v ON_ERROR_STOP=1 \
    -h '$SERVICE_HOST' \
    -p '$SERVICE_PORT' \
    -U '$ADMIN_USER' \
    -d '$CLUSTER_DATABASE' \
    -c \"update public.users set auth_issuer = '$NEW_ISSUER', auth_subject = '$NEW_SUBJECT' where email = '$WESEN_EMAIL';\""

kubectl -n "$CLUSTER_POSTGRES_NAMESPACE" exec "$CLUSTER_POSTGRES_STATEFULSET-0" -- sh -lc \
  "export PGPASSWORD='$ADMIN_PASSWORD'; psql \
    -v ON_ERROR_STOP=1 \
    -h '$SERVICE_HOST' \
    -p '$SERVICE_PORT' \
    -U '$ADMIN_USER' \
    -d '$CLUSTER_DATABASE' \
    -At -c \"select email, auth_issuer, auth_subject from public.users where email = '$WESEN_EMAIL';\""

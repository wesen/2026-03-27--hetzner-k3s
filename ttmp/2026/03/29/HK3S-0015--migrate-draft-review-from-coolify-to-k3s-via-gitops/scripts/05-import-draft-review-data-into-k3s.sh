#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./00-common.sh
source "$SCRIPT_DIR/00-common.sh"

require_cmd kubectl

DUMP_PATH="${1:-$VAR_DIR/hosted-draft-review-data.sql}"

if [[ ! -f "$DUMP_PATH" ]]; then
  echo "missing dump file: $DUMP_PATH" >&2
  exit 1
fi

ADMIN_USER="$(cluster_admin_user)"
ADMIN_PASSWORD="$(cluster_admin_password)"
SERVICE_HOST="$(cluster_service_host)"
SERVICE_PORT="$(cluster_service_port)"
REMOTE_DUMP_PATH="/tmp/draft-review-import.sql"
WRAPPED_DUMP_PATH="${VAR_DIR}/hosted-draft-review-data.wrapped.sql"

kubectl -n "$CLUSTER_POSTGRES_NAMESPACE" exec -i "$CLUSTER_POSTGRES_STATEFULSET-0" -- sh -lc \
  "export PGPASSWORD='$ADMIN_PASSWORD'; psql \
    -v ON_ERROR_STOP=1 \
    -h '$SERVICE_HOST' \
    -p '$SERVICE_PORT' \
    -U '$ADMIN_USER' \
    -d '$CLUSTER_DATABASE'" <<'SQL'
BEGIN;
TRUNCATE TABLE
  public.article_assets,
  public.article_reaction_types,
  public.article_sections,
  public.article_versions,
  public.articles,
  public.author_sessions,
  public.default_reaction_types,
  public.email_verification_tokens,
  public.password_reset_tokens,
  public.reactions,
  public.reader_invites,
  public.review_paragraph_progress,
  public.review_section_progress,
  public.review_sessions,
  public.review_summaries,
  public.users
RESTART IDENTITY CASCADE;
COMMIT;
SQL

{
  printf 'SET session_replication_role = replica;\n'
  cat "$DUMP_PATH"
  printf '\nSET session_replication_role = origin;\n'
} >"$WRAPPED_DUMP_PATH"

kubectl cp "$WRAPPED_DUMP_PATH" "${CLUSTER_POSTGRES_NAMESPACE}/${CLUSTER_POSTGRES_STATEFULSET}-0:${REMOTE_DUMP_PATH}"

kubectl -n "$CLUSTER_POSTGRES_NAMESPACE" exec "$CLUSTER_POSTGRES_STATEFULSET-0" -- sh -lc \
  "export PGPASSWORD='$ADMIN_PASSWORD'; \
   psql \
     -v ON_ERROR_STOP=1 \
     -h '$SERVICE_HOST' \
     -p '$SERVICE_PORT' \
     -U '$ADMIN_USER' \
     -d '$CLUSTER_DATABASE' \
     -f '$REMOTE_DUMP_PATH' && \
   rm -f '$REMOTE_DUMP_PATH'"

echo "imported $DUMP_PATH into $CLUSTER_DATABASE"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./00-common.sh
source "$SCRIPT_DIR/00-common.sh"

require_cmd kubectl
require_cmd curl

ADMIN_USER="$(cluster_admin_user)"
ADMIN_PASSWORD="$(cluster_admin_password)"
SERVICE_HOST="$(cluster_service_host)"
SERVICE_PORT="$(cluster_service_port)"
NEW_SUBJECT="$(terraform_wesen_subject)"

echo "health:"
curl --fail --silent --show-error "https://draft-review.yolo.scapegoat.dev/healthz"
echo

echo "target durable table counts:"
kubectl -n "$CLUSTER_POSTGRES_NAMESPACE" exec "$CLUSTER_POSTGRES_STATEFULSET-0" -- sh -lc \
  "export PGPASSWORD='$ADMIN_PASSWORD'; psql \
    -v ON_ERROR_STOP=1 \
    -h '$SERVICE_HOST' \
    -p '$SERVICE_PORT' \
    -U '$ADMIN_USER' \
    -d '$CLUSTER_DATABASE' \
    -At -c \"select 'articles', count(*) from public.articles union all select 'article_versions', count(*) from public.article_versions union all select 'reader_invites', count(*) from public.reader_invites union all select 'review_summaries', count(*) from public.review_summaries union all select 'users', count(*) from public.users union all select 'article_reaction_types', count(*) from public.article_reaction_types union all select 'default_reaction_types', count(*) from public.default_reaction_types union all select 'article_sections', count(*) from public.article_sections union all select 'reactions', count(*) from public.reactions union all select 'review_section_progress', count(*) from public.review_section_progress union all select 'review_paragraph_progress', count(*) from public.review_paragraph_progress order by 1\""

echo
echo "wesen row:"
kubectl -n "$CLUSTER_POSTGRES_NAMESPACE" exec "$CLUSTER_POSTGRES_STATEFULSET-0" -- sh -lc \
  "export PGPASSWORD='$ADMIN_PASSWORD'; psql \
    -v ON_ERROR_STOP=1 \
    -h '$SERVICE_HOST' \
    -p '$SERVICE_PORT' \
    -U '$ADMIN_USER' \
    -d '$CLUSTER_DATABASE' \
    -At -c \"select email, name, auth_issuer, auth_subject from public.users where email = '$WESEN_EMAIL';\""

echo
echo "expected issuer: $NEW_ISSUER"
echo "expected subject: $NEW_SUBJECT"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TICKET_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$TICKET_ROOT/../../../../.." && pwd)"
TERRAFORM_ROOT="/home/manuel/code/wesen/terraform"
VAR_DIR="$TICKET_ROOT/var"

mkdir -p "$VAR_DIR"

HOSTED_HOST="${HOSTED_HOST:-89.167.52.236}"
HOSTED_POSTGRES_CONTAINER="${HOSTED_POSTGRES_CONTAINER:-go1o5tbegalwy3kesshq3hcp}"
HOSTED_DATABASE="${HOSTED_DATABASE:-draft_review}"

CLUSTER_NAMESPACE="${CLUSTER_NAMESPACE:-draft-review}"
CLUSTER_POSTGRES_NAMESPACE="${CLUSTER_POSTGRES_NAMESPACE:-postgres}"
CLUSTER_POSTGRES_STATEFULSET="${CLUSTER_POSTGRES_STATEFULSET:-postgres}"
CLUSTER_POSTGRES_SECRET="${CLUSTER_POSTGRES_SECRET:-draft-review-postgres-admin}"
CLUSTER_DATABASE="${CLUSTER_DATABASE:-draft_review}"

OLD_ISSUER="${OLD_ISSUER:-https://auth.scapegoat.dev/realms/draft-review}"
NEW_ISSUER="${NEW_ISSUER:-https://auth.yolo.scapegoat.dev/realms/draft-review}"
WESEN_EMAIL="${WESEN_EMAIL:-wesen@ruinwesen.com}"

export KUBECONFIG="${KUBECONFIG:-$REPO_ROOT/kubeconfig-91.98.46.169.yaml}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

cluster_secret_value() {
  local key="$1"
  kubectl -n "$CLUSTER_NAMESPACE" get secret "$CLUSTER_POSTGRES_SECRET" -o "jsonpath={.data.${key}}" | base64 -d
}

cluster_admin_user() {
  cluster_secret_value postgres-user
}

cluster_admin_password() {
  cluster_secret_value postgres-password
}

cluster_service_host() {
  cluster_secret_value service-host
}

cluster_service_port() {
  cluster_secret_value service-port
}

terraform_wesen_subject() {
  AWS_PROFILE="${AWS_PROFILE_TERRAFORM:-manuel}" terraform -chdir="$TERRAFORM_ROOT/keycloak/apps/draft-review/envs/k3s-parallel" output -raw wesen_user_id
}

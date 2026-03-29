#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./00-common.sh
source "$SCRIPT_DIR/00-common.sh"

require_cmd kubectl
require_cmd sha256sum

OUTPUT_PATH="${1:-$VAR_DIR/k3s-draft-review-pre-import.sql}"
RAW_OUTPUT_PATH="${OUTPUT_PATH}.raw"
ADMIN_USER="$(cluster_admin_user)"
ADMIN_PASSWORD="$(cluster_admin_password)"
SERVICE_HOST="$(cluster_service_host)"
SERVICE_PORT="$(cluster_service_port)"

kubectl -n "$CLUSTER_POSTGRES_NAMESPACE" exec "$CLUSTER_POSTGRES_STATEFULSET-0" -- sh -lc \
  "export PGPASSWORD='$ADMIN_PASSWORD'; pg_dump \
    -h '$SERVICE_HOST' \
    -p '$SERVICE_PORT' \
    -U '$ADMIN_USER' \
    -d '$CLUSTER_DATABASE' \
    --data-only \
    --column-inserts \
    --disable-dollar-quoting \
    --no-owner \
    --no-privileges" \
  >"$RAW_OUTPUT_PATH"

python3 - "$RAW_OUTPUT_PATH" "$OUTPUT_PATH" <<'PY'
from pathlib import Path
import sys

raw = Path(sys.argv[1])
out = Path(sys.argv[2])

skip_prefixes = ("\\restrict ", "\\unrestrict ")
skip_exact = {"SET transaction_timeout = 0;"}

with raw.open() as src, out.open("w") as dst:
    for line in src:
        stripped = line.rstrip("\n")
        if stripped in skip_exact:
            continue
        if any(stripped.startswith(prefix) for prefix in skip_prefixes):
            continue
        dst.write(line)

raw.unlink()
PY

echo "wrote K3s Draft Review snapshot to $OUTPUT_PATH"
sha256sum "$OUTPUT_PATH"

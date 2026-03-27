#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <server-ip>" >&2
  exit 1
fi

SERVER_IP="$1"
OUTFILE="kubeconfig-${SERVER_IP}.yaml"

scp "root@${SERVER_IP}:/etc/rancher/k3s/k3s.yaml" "${OUTFILE}"

python - <<PY
from pathlib import Path
p = Path("${OUTFILE}")
text = p.read_text()
text = text.replace("127.0.0.1", "${SERVER_IP}")
p.write_text(text)
PY

echo "wrote ${OUTFILE}"

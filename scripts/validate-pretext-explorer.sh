#!/usr/bin/env bash

set -euo pipefail

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || {
    echo "missing required environment variable: $name" >&2
    exit 1
  }
}

require_env KUBECONFIG

kubectl -n argocd get application pretext \
  -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{"\n"}'

kubectl -n pretext get deploy pretext-explorer \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

kubectl -n pretext get ingress pretext-explorer \
  -o jsonpath='{.spec.rules[0].host}{"\n"}'

curl -fsSL https://pretext.yolo.scapegoat.dev/ | rg -n "Pretext Explorer|How Text Layout Actually Works"

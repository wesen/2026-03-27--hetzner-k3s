#!/usr/bin/env bash

set -euo pipefail

repo_root="/home/manuel/code/wesen/2026-03-27--hetzner-k3s"
export KUBECONFIG="${repo_root}/kubeconfig-91.98.46.169.yaml"

kubectl -n argocd get application draft-review -o jsonpath='{.status.sync.status} {.status.health.status} {.status.sync.revision}{"\n"}'
kubectl -n draft-review rollout status deployment/draft-review --timeout=300s >/dev/null
kubectl -n draft-review get secret draft-review-runtime >/dev/null
kubectl -n draft-review get secret draft-review-ghcr-pull -o jsonpath='{.type}{"\n"}'
curl -fsS https://draft-review.yolo.scapegoat.dev/healthz
curl -fsS https://draft-review.yolo.scapegoat.dev/api/info | jq '{authMode: .data.authMode, issuerUrl: .data.issuerUrl}'

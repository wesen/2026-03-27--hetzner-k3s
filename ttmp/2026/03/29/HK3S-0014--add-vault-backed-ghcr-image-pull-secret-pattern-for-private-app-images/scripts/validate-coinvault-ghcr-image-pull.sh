#!/usr/bin/env bash

set -euo pipefail

repo_dir="/home/manuel/code/wesen/2026-03-27--hetzner-k3s"
export KUBECONFIG="${repo_dir}/kubeconfig-91.98.46.169.yaml"

kubectl -n coinvault get secret coinvault-ghcr-pull -o jsonpath='{.type}{"\n"}'
kubectl -n coinvault get secret coinvault-ghcr-pull -o json | jq -r '.data | keys[]'
kubectl -n coinvault get serviceaccount coinvault -o jsonpath='{.imagePullSecrets[*].name}{"\n"}'
kubectl -n coinvault get deployment coinvault -o jsonpath='{.spec.template.spec.containers[0].image}{" "}{.spec.template.spec.containers[0].imagePullPolicy}{"\n"}'
curl -fsS https://coinvault.yolo.scapegoat.dev/healthz | jq '{ok, profile_registries: .chat.profile_registries}'
kubectl -n argocd get application coinvault -o jsonpath='{.status.sync.status} {.status.health.status} {.status.sync.revision}{"\n"}'

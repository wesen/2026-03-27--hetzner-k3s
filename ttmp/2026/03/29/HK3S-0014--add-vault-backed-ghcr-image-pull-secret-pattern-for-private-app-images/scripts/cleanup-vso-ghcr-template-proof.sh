#!/usr/bin/env bash

set -euo pipefail

repo_dir="/home/manuel/code/wesen/2026-03-27--hetzner-k3s"

source "${repo_dir}/.envrc" >/dev/null 2>&1

export VAULT_ADDR="${VAULT_ADDR:-https://vault.yolo.scapegoat.dev}"
vault_note="$(op read 'op://Private/vault yolo scapegoat dev k3s init 2026-03-27/notesPlain')"
export VAULT_TOKEN="$(printf '%s\n' "${vault_note}" | awk '/^Root token:/{getline;print;exit}')"
export KUBECONFIG="${repo_dir}/kubeconfig-91.98.46.169.yaml"

kubectl -n vault-secrets-operator-smoke delete vaultstaticsecret vso-ghcr-template-inspect --ignore-not-found
kubectl -n vault-secrets-operator-smoke delete secret vso-ghcr-template-inspect --ignore-not-found
vault kv delete kv/apps/vso-smoke/dev/ghcr-template >/dev/null

echo "removed temporary VSO template proof resources"

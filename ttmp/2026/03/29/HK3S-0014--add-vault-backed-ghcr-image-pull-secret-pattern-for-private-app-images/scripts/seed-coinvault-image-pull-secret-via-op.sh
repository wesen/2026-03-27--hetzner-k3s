#!/usr/bin/env bash

set -euo pipefail

ticket_dir="/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/29/HK3S-0014--add-vault-backed-ghcr-image-pull-secret-pattern-for-private-app-images"
repo_dir="/home/manuel/code/wesen/2026-03-27--hetzner-k3s"

source "${repo_dir}/.envrc" >/dev/null 2>&1

export VAULT_ADDR="${VAULT_ADDR:-https://vault.yolo.scapegoat.dev}"
vault_note="$(op read 'op://Private/vault yolo scapegoat dev k3s init 2026-03-27/notesPlain')"
export VAULT_TOKEN="$(printf '%s\n' "${vault_note}" | awk '/^Root token:/{getline;print;exit}')"
export GITHUB_DEPLOY_USERNAME="${GITHUB_DEPLOY_USERNAME:-wesen}"

"${ticket_dir}/scripts/bootstrap-coinvault-image-pull-secret.sh"

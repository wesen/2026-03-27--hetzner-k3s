# Changelog

## 2026-03-29

- Initial workspace created

## 2026-03-29

Added the initial design, implementation playbook, and task inventory for Vault-backed GHCR image pull secrets, using CoinVault’s private-package rollout failure as the motivating example.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/29/HK3S-0014--add-vault-backed-ghcr-image-pull-secret-pattern-for-private-app-images/design-doc/01-vault-backed-ghcr-image-pull-secret-pattern-for-private-app-images.md — Primary design guide
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/29/HK3S-0014--add-vault-backed-ghcr-image-pull-secret-pattern-for-private-app-images/playbook/01-implement-vault-backed-ghcr-image-pull-secrets-in-k3s.md — Step-by-step implementation plan
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/29/HK3S-0014--add-vault-backed-ghcr-image-pull-secret-pattern-for-private-app-images/reference/01-investigation-diary-for-vault-backed-ghcr-image-pull-secrets.md — Research and investigation diary

## 2026-03-29

Locked the first implementation decisions before touching secrets: use `GITHUB_DEPLOY_PAT` only as the local bootstrap source, store the credential at `kv/apps/coinvault/prod/image-pull`, and rely on `VaultStaticSecret` destination templating to render `.dockerconfigjson` directly.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/29/HK3S-0014--add-vault-backed-ghcr-image-pull-secret-pattern-for-private-app-images/tasks.md — Task list updated with the concrete decisions
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/29/HK3S-0014--add-vault-backed-ghcr-image-pull-secret-pattern-for-private-app-images/reference/01-investigation-diary-for-vault-backed-ghcr-image-pull-secrets.md — Diary updated with the `kubectl explain` evidence for VSO templating support

## 2026-03-29

Added the first GitOps implementation scaffold: a CoinVault image-pull Vault bootstrap helper, a `VaultStaticSecret` that renders `.dockerconfigjson`, and `ServiceAccount` wiring for `imagePullSecrets`.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-coinvault-image-pull-secret.sh — Local operator bootstrap helper for writing the GHCR credential into Vault
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/vault-static-secret-image-pull.yaml — New image-pull secret render resource
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/serviceaccount.yaml — ServiceAccount now prepared for `imagePullSecrets`
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/kustomization.yaml — Includes the new resource in the CoinVault package

---
Title: Draft Review K3s migration playbook
Ticket: HK3S-0015
Status: active
Topics:
    - draft-review
    - k3s
    - gitops
    - keycloak
    - postgres
    - ghcr
    - vault
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: Step-by-step migration playbook for recreating Draft Review on the K3s platform.
LastUpdated: 2026-03-29T11:05:00-04:00
WhatFor: Give operators a concrete sequence to package and deploy Draft Review on K3s.
WhenToUse: Use when executing the Draft Review migration ticket.
---

# Draft Review K3s migration playbook

## Purpose

This playbook turns the migration design into a concrete execution sequence.

The important principle is: do not start by writing random Kubernetes YAML. First establish the source-repo release path, then the identity and database prerequisites, then the GitOps package.

## Planned execution order

1. Source repo packaging
2. Keycloak parallel env
3. Vault secret contract
4. Postgres bootstrap and runtime secret
5. K3s package and Argo app
6. Rollout and validation
7. Docs and closeout

## Commands we expect to use

```bash
# Source repo
cd /home/manuel/code/wesen/2026-03-24--draft-review
git status --short
go test ./cmd/... ./pkg/...
docker build -t draft-review:local .

# Terraform Keycloak repo
cd /home/manuel/code/wesen/terraform
terraform -chdir=keycloak/apps/draft-review/envs/<env> validate
terraform -chdir=keycloak/apps/draft-review/envs/<env> plan

# K3s repo
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml
kubectl -n argocd get applications
kubectl kustomize gitops/kustomize/draft-review
./ttmp/2026/03/29/HK3S-0015--migrate-draft-review-from-coolify-to-k3s-via-gitops/scripts/01-seed-draft-review-vault-secrets.sh
./ttmp/2026/03/29/HK3S-0015--migrate-draft-review-from-coolify-to-k3s-via-gitops/scripts/02-validate-draft-review-k3s.sh
./ttmp/2026/03/29/HK3S-0015--migrate-draft-review-from-coolify-to-k3s-via-gitops/scripts/03-export-hosted-draft-review-db.sh
./ttmp/2026/03/29/HK3S-0015--migrate-draft-review-from-coolify-to-k3s-via-gitops/scripts/04-snapshot-k3s-draft-review-db.sh
./ttmp/2026/03/29/HK3S-0015--migrate-draft-review-from-coolify-to-k3s-via-gitops/scripts/05-import-draft-review-data-into-k3s.sh
./ttmp/2026/03/29/HK3S-0015--migrate-draft-review-from-coolify-to-k3s-via-gitops/scripts/06-rewrite-draft-review-wesen-identity.sh
./ttmp/2026/03/29/HK3S-0015--migrate-draft-review-from-coolify-to-k3s-via-gitops/scripts/07-validate-draft-review-data-migration.sh
```

## Exit criteria

- Draft Review source repo can publish to GHCR and open GitOps PRs
- Draft Review runtime secrets are stored in Vault and synced by VSO
- Draft Review can pull its image through the private GHCR pull-secret pattern
- Draft Review has a dedicated database and role on shared cluster Postgres
- Draft Review authenticates against K3s Keycloak on the parallel hostname
- `https://draft-review.yolo.scapegoat.dev` works end to end
- hosted Draft Review data has been imported into the cluster DB
- the `wesen` author row points at the K3s issuer and K3s Keycloak subject
- browser login as `wesen` shows the imported Draft Review content on K3s

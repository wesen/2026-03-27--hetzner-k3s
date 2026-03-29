---
Title: Draft Review K3s migration design and implementation guide
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
DocType: design-doc
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: Detailed intern-facing design and implementation guide for recreating Draft Review on the K3s platform.
LastUpdated: 2026-03-29T11:05:00-04:00
WhatFor: Explain how Draft Review should be packaged, deployed, authenticated, and validated on the K3s platform.
WhenToUse: Use when implementing or reviewing the Draft Review K3s migration.
---

# Draft Review K3s migration design and implementation guide

## Executive summary

Draft Review is a private Go application with an embedded frontend, a PostgreSQL database, browser OIDC authentication through Keycloak, and persisted uploaded media.

The migration goal is not to reproduce Coolify mechanics. It is to recreate the deployment on the K3s platform using the patterns already established in this repository:

- source repo owns code, tests, Docker packaging, GHCR publishing, and GitOps PR creation
- this repo owns Kubernetes manifests, Argo CD applications, Vault and VSO wiring, storage, and ingress
- shared platform services provide Postgres and Keycloak

The intended parallel target is:

- `https://draft-review.yolo.scapegoat.dev`

This keeps the current hosted deployment untouched while the K3s deployment is packaged, validated, and stabilized.

## Current system shape

The current Coolify deployment tells us what must survive the migration:

- public URL: `https://draft-review.app.scapegoat.dev`
- OIDC issuer: `https://auth.scapegoat.dev/realms/draft-review`
- OIDC client: `draft-review-web`
- backend process: `draft-review serve`
- database: PostgreSQL `draft_review`
- persistent data: uploaded media under `--media-root`

Important runtime variables from the current hosted docs:

- `DRAFT_REVIEW_DSN`
- `DRAFT_REVIEW_AUTH_MODE=oidc`
- `DRAFT_REVIEW_AUTH_SESSION_SECRET`
- `DRAFT_REVIEW_AUTH_SESSION_TTL`
- `DRAFT_REVIEW_AUTH_SESSION_SLIDING_RENEWAL`
- `DRAFT_REVIEW_AUTH_SESSION_RENEW_BEFORE`
- `DRAFT_REVIEW_OIDC_ISSUER_URL`
- `DRAFT_REVIEW_OIDC_CLIENT_ID`
- `DRAFT_REVIEW_OIDC_CLIENT_SECRET`
- `DRAFT_REVIEW_OIDC_REDIRECT_URL`

That runtime contract should be recreated, not redesigned casually during the migration.

## Target architecture

```text
Draft Review source repo
  -> GitHub Actions
  -> GHCR image
  -> GitOps PR into K3s repo

K3s repo
  -> Draft Review namespace and package
  -> Vault/VSO runtime secret
  -> Vault/VSO GHCR pull secret
  -> Postgres bootstrap job for draft_review database/user
  -> PVC for media uploads
  -> Service + Ingress
  -> Argo CD Application

Platform services
  -> PostgreSQL cluster
  -> Keycloak on K3s
  -> Vault and VSO
```

## Required migration components

### 1. Source repo packaging

The Draft Review source repo should follow the same packaging standard already documented for `mysql-ide` and `coinvault`:

- add a GitHub Actions workflow to test and publish the image
- add `deploy/gitops-targets.json`
- add `scripts/open_gitops_pr.py`
- document the release path in the source repo README

Because the source repo is private, the package will likely also be private unless that policy is changed explicitly.

### 2. Private GHCR pull path

Draft Review should reuse the implemented `HK3S-0014` pattern:

```text
Vault
  -> kv/apps/draft-review/prod/image-pull
  -> VSO
  -> kubernetes.io/dockerconfigjson secret
  -> ServiceAccount.imagePullSecrets
```

This is important because a successful GHCR publish alone does not mean kubelet can pull the image.

### 3. PostgreSQL database bootstrap

Draft Review should not get its own PostgreSQL server. It should get its own database and role on the shared cluster Postgres.

Use the documented Vault-backed bootstrap-job pattern:

- admin credentials come from Vault
- app credentials come from Vault
- a bootstrap job creates:
  - database `draft_review`
  - role `draft_review`
  - grants/ownership

The resulting DSN should point at the shared service, not a local app-side Postgres.

### 4. Keycloak realm and client

Draft Review already has a hosted Keycloak Terraform env. The K3s migration should create a parallel env, not mutate the hosted one immediately.

Expected result:

- parallel Keycloak env under the Terraform repo
- issuer on K3s Keycloak:
  - `https://auth.yolo.scapegoat.dev/realms/draft-review`
- redirect URL:
  - `https://draft-review.yolo.scapegoat.dev/auth/callback`
- post-logout redirect:
  - `https://draft-review.yolo.scapegoat.dev/auth/logout/callback*`

### 5. Runtime secret delivery

Draft Review needs at least:

- DSN
- session secret
- OIDC client secret
- issuer URL
- redirect URL
- media root or equivalent file path settings if they are environment-driven

These should be stored in Vault and synced with VSO into a namespace-local secret.

### 6. Persistent media storage

The README explicitly says uploaded media must not live only in the container filesystem.

So the K3s package needs:

- a PVC
- a mounted media path
- deployment wiring so `--media-root` points at that mounted directory

### 7. GitOps package

The K3s repo should own a dedicated package for Draft Review with at least:

- `namespace.yaml`
- `serviceaccount.yaml`
- `vault-auth.yaml`
- `vault-static-secret-runtime.yaml`
- `vault-static-secret-image-pull.yaml`
- `persistentvolumeclaim.yaml`
- `deployment.yaml`
- `service.yaml`
- `ingress.yaml`
- `kustomization.yaml`
- `gitops/applications/draft-review.yaml`

## Proposed migration sequence

1. Package the source repo for GHCR + GitOps PRs.
2. Add the parallel Keycloak env in Terraform.
3. Add the K3s package and Argo application.
4. Bootstrap Vault secrets and the Postgres DB/user.
5. Deploy to `draft-review.yolo.scapegoat.dev`.
6. Validate:
   - healthz
   - `/api/info`
   - OIDC login
   - DB-backed behavior
   - media upload persistence
7. Only after that, discuss any cutover from the Coolify endpoint.

## Validation checklist

```text
Argo app is Synced Healthy
Deployment is Ready
Healthz succeeds
API info reports auth-mode=oidc
Login redirects into the K3s Keycloak realm
Callback succeeds
Authenticated /api/me works
Database-backed article routes work
Media upload persists across pod restart
Image can be pulled without node-local cache tricks
```

## Non-goals for the first migration slice

- decommissioning the Coolify app immediately
- moving the original `draft-review.app.scapegoat.dev` hostname
- redesigning Draft Review’s auth/session semantics
- changing the app from shared Postgres to its own database server

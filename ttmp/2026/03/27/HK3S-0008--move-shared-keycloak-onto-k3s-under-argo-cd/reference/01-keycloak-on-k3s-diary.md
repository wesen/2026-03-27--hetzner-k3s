---
Title: Keycloak on K3s implementation diary
Ticket: HK3S-0008
Status: active
Topics:
    - keycloak
    - k3s
    - gitops
    - postgresql
    - vault
DocType: reference
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: Chronological diary for turning the deferred Keycloak-on-K3s ticket into an executable implementation plan and rollout.
LastUpdated: 2026-03-28T15:56:50-04:00
WhatFor: Use this to review the exact decisions, failures, and implementation path for HK3S-0008.
WhenToUse: Read this when continuing or reviewing the Keycloak-on-K3s migration work.
---

# Keycloak on K3s implementation diary

## Goal

Move shared Keycloak onto K3s under Argo CD without losing the current external Keycloak rollback path, and now do it using the shared PostgreSQL service that already exists on the cluster.

## Step 1: Tighten the ticket now that PostgreSQL is live and define the correct database-provisioning pattern

The original version of this ticket was still mostly a placeholder. It correctly deferred the move, but it left a lot of important implementation questions too open because the platform was not ready yet. That changed after Vault, VSO, the first migrated app, and shared PostgreSQL all became live.

The first thing I did in this implementation pass was tighten the ticket around one concrete operational conclusion: if Keycloak moves onto K3s, it should use the shared PostgreSQL service and should not use Terraform to create its internal database and role.

That required a reusable pattern doc, because the same question is going to come up again for future apps: “How do we declaratively create PostgreSQL internal objects if Kubernetes can only manage the server?” I wrote the answer down in:

- [vault-backed-postgres-bootstrap-job-pattern.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/vault-backed-postgres-bootstrap-job-pattern.md)

The conclusion is:

- use Vault as the source of truth
- use VSO to sync the secrets
- use an idempotent bootstrap `Job` to create the application database and role
- keep the application deployment on a least-privilege runtime credential

Then I updated HK3S-0008 itself so it is no longer just “maybe one day move Keycloak”:

- shared PostgreSQL is now the preferred backing store
- the bootstrap `Job` pattern is the intended way to provision Keycloak’s database
- the next implementation question is packaging and rollout, not whether the cluster can plausibly host the service

### What I did
- Added the reusable docs page for Vault-backed PostgreSQL bootstrap Jobs.
- Added a real design doc for HK3S-0008.
- Added this diary so the implementation trail is recorded as the ticket moves from deferred planning into actual rollout.
- Updated the index, task list, and plan to reflect that shared PostgreSQL now changes the shape of the ticket.

### Why
- The ticket needed a stronger default implementation path before any manifests were added.
- The PostgreSQL bootstrap pattern is a platform concern, not just a Keycloak concern.

### What worked
- The new docs unify the database-provisioning answer with the existing Vault/VSO and Argo CD model.
- The ticket can now be executed task by task instead of requiring fresh design work from scratch.

### What didn't work
- Nothing failed technically yet, but the old ticket text was no longer precise enough to guide safe implementation.

### What I learned
- Once shared PostgreSQL exists, the most important decision is not “should Keycloak use a database?” It is “who owns the creation of the database and role?”

### What should be done in the future
- Choose the packaging model explicitly and start the actual Keycloak package scaffold.

## Step 2: Turn the design into a real GitOps package and bootstrap toolchain

With the database-provisioning pattern decided, the next task was to stop talking abstractly about Keycloak and give the ticket a concrete package. I chose the same repo-owned manifest style that already succeeded for the shared MySQL, PostgreSQL, and Redis services, instead of reaching for a vendor chart. That keeps the runtime explicit and easier to debug.

The package now exists in:

- [`gitops/applications/keycloak.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/keycloak.yaml)
- [`gitops/kustomize/keycloak/kustomization.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/kustomization.yaml)

The important implementation choices I encoded were:

- parallel hostname: `auth.yolo.scapegoat.dev`
- official Keycloak image: `quay.io/keycloak/keycloak:26.1.0`
- shared PostgreSQL backing store at `postgres.postgres.svc.cluster.local:5432`
- two service accounts:
  - `keycloak`
  - `keycloak-db-bootstrap`
- Vault and VSO secret flow for:
  - runtime DB credential
  - bootstrap admin credential
  - PostgreSQL bootstrap credential for the Job
- an Argo `PreSync` Job that creates:
  - database `keycloak`
  - role `keycloak_app`

I also added the local helpers needed to seed and validate the deployment:

- [`scripts/bootstrap-keycloak-secrets.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-keycloak-secrets.sh)
- [`scripts/validate-keycloak.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-keycloak.sh)

The first validation pass was purely structural:

- `bash -n scripts/bootstrap-keycloak-secrets.sh`
- `bash -n scripts/validate-keycloak.sh`
- `kubectl kustomize gitops/kustomize/keycloak`
- `git diff --check`

That all passed. One small portability issue did show up while reviewing the rendered ConfigMap script: I had written the bootstrap shell with `set -euo pipefail` under `/bin/sh`. That is not the right assumption for the stock shell inside `postgres:16-alpine`, so I tightened it to `set -eu` and rewrote the database-existence check without relying on `pipefail`.

I also tried a server dry-run against the cluster:

- `kubectl apply --dry-run=server -f gitops/applications/keycloak.yaml`
- `kubectl apply --dry-run=server -k gitops/kustomize/keycloak`

The application manifest validated. The Kustomize package hit the expected namespace-not-found limitation of server dry-run because the target namespace does not exist yet and the dry-run does not stage earlier namespace creation for later objects. That is not a design problem; it is a known limitation of validating a package that creates its own namespace.

### What I did
- Chose repo-owned manifests and the parallel hostname.
- Added the Keycloak Argo application and Kustomize package.
- Added the Vault policies, roles, and bootstrap helpers.
- Added the PostgreSQL bootstrap `Job`.
- Added the initial deployment, service, and ingress.
- Fixed the bootstrap script portability issue before rollout.

### Why
- The repo-owned manifest path fits the rest of the cluster and avoids chart-induced surprises.
- The `PreSync` Job lets Argo own the database bootstrap without making the running Keycloak pod privileged.

### What worked
- The render and local static validation passed cleanly.
- The Vault policy split matched the intended service-account boundaries.
- The package structure now aligns with the rest of the cluster.

### What didn't work
- The first draft of the bootstrap shell was too optimistic about `pipefail` support under `/bin/sh`.
- Server-side dry-run could not fully validate namespaced objects before the namespace exists, which is expected but still worth recording.

### What I learned
- The parallel-host Keycloak rollout is now mostly an operator bootstrap problem, not a packaging problem.

### What should be done in the future
- Seed the Vault secret paths, re-run the Vault Kubernetes-auth bootstrap so the new roles exist, and deploy the Argo application.

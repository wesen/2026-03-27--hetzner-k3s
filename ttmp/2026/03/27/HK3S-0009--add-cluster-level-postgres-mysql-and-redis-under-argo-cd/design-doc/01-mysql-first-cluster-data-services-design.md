---
Title: MySQL-first cluster data services design
Ticket: HK3S-0009
Status: active
Topics:
    - k3s
    - infra
    - gitops
    - migration
DocType: design-doc
Intent: long-term
Owners: []
RelatedFiles:
    - Path: gitops/kustomize/demo-stack/postgres-statefulset.yaml
      Note: Current in-repo baseline for app-local stateful services
    - Path: ttmp/2026/03/27/HK3S-0007--recreate-the-first-application-on-k3s-using-vault-managed-secrets/index.md
      Note: CoinVault migration that exposed the MySQL dependency mismatch
ExternalSources:
    - https://raw.githubusercontent.com/bitnami/charts/main/bitnami/mysql/Chart.yaml
    - https://raw.githubusercontent.com/bitnami/charts/main/bitnami/mysql/values.yaml
    - https://charts.bitnami.com/bitnami/index.yaml
Summary: Design record for implementing shared MySQL first on K3s, leaving PostgreSQL and Redis for later slices.
LastUpdated: 2026-03-27T16:26:00-04:00
WhatFor: Explain why MySQL is being implemented first, which packaging model it uses, and how Vault/VSO should deliver credentials into the deployment.
WhenToUse: Read this before scaffolding or reviewing the shared MySQL deployment.
---

# MySQL-first cluster data services design

## Executive Summary

We should implement MySQL first, not all three planned data services. CoinVault exposed an immediate need for a stable in-cluster MySQL endpoint because its current host is a Coolify-internal alias that K3s cannot resolve. The cleanest dependable first slice is a shared MySQL deployment under Argo CD using repo-managed Kustomize manifests and the official `mysql:8.4` image, with credentials delivered from Vault through VSO into a normal Kubernetes `Secret`.

## Problem Statement

The original ticket grouped PostgreSQL, MySQL, and Redis into one later platform phase. That broad framing is no longer ideal. We now have a concrete blocker:

- CoinVault expects MySQL
- its current MySQL host only exists inside Coolify networking
- K3s cannot use that host

So we need one shared MySQL service now, not a speculative multi-database platform build.

## Proposed Solution

Implement one Argo CD-managed MySQL deployment with these properties:

- namespace: `mysql`
- packaging: repo-managed Kustomize manifests
- architecture: standalone
- persistence: `local-path` PVC
- secret delivery: VSO-synced destination secret named `mysql-auth`
- first tenant: CoinVault

The first password secret should contain the keys the chart expects:

- `mysql-root-password`
- `mysql-password`
- `mysql-replication-password`

Those values should come from Vault, not be committed in Git.

## Design Decisions

### Decision 1: MySQL first, not Postgres or Redis

We are choosing MySQL because it solves a live blocker for the current application migration. Postgres and Redis can wait until they have equally concrete consumers.

### Decision 2: Use repo-managed Kustomize manifests instead of the external Bitnami chart

I initially tried the Bitnami chart because it looked like the smallest path and its documented `auth.existingSecret` support fit the Vault/VSO model. But the live rollout exposed two concrete supply-chain problems:

- the GitHub chart tree version and the published Bitnami chart repository version diverged
- the published chart referenced a `docker.io/bitnami/mysql` image tag that no longer existed

Those are not design-time concerns. They are operational failures on the path Argo CD would actually use. So the better engineering choice for this cluster is to own the MySQL manifests in this repo.

The repo-managed Kustomize approach still provides:

- explicit persistence handling
- explicit service wiring
- explicit health probes
- explicit image pinning
- a smaller debugging surface when something breaks

### Decision 3: Keep VSO as the secret-delivery boundary

Even though the runtime packaging changed, the secret model did not. VSO is still the right fit because:

- Vault remains the secret source of truth
- Kubernetes still gets a native `Secret`
- the StatefulSet consumes a normal Kubernetes interface

### Decision 4: Accept a single shared MySQL instance with the first app-specific database/user

For the first slice, we do not need full multi-tenant abstractions. We need:

- one MySQL instance
- one first application database/user
- a documented path to add more later

## Alternatives Considered

### Alternative 1: Finish CoinVault against the old external MySQL host

Rejected because the host is not routable from K3s.

### Alternative 2: Skip straight to PostgreSQL or Redis too

Rejected because that would widen the scope without solving a current blocker faster.

### Alternative 3: Use the Bitnami chart anyway and override around the broken image path

Rejected because by the time the chart, repository, and image publication issues showed up together, the repo-owned manifest path had become simpler and more reliable than trying to outsmart the broken external dependency chain.

## Implementation Plan

1. Add the MySQL-first design and diary artifacts.
2. Add a Vault Kubernetes-auth policy and role for the MySQL service account.
3. Add an Argo CD application that points at `gitops/kustomize/mysql`.
4. Configure the repo-managed manifests to consume a VSO-managed `mysql-auth` secret.
5. Add helper scripts to seed Vault and validate the deployment.
6. Deploy and validate the shared MySQL instance.
7. Update CoinVault to consume the in-cluster MySQL host.

## Open Questions

- Should the first CoinVault database/user be created by chart defaults or by an explicit init script?
- Do we want metrics enabled in the first slice, or only after the service is stable?
- When we later add Postgres, should it copy the same chart-plus-VSO pattern or use an operator?

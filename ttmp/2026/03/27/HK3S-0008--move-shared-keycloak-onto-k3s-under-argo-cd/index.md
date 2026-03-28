---
Title: Move shared Keycloak onto K3s under Argo CD
Ticket: HK3S-0008
Status: active
Topics:
    - vault
    - k3s
    - infra
    - gitops
    - migration
DocType: index
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ttmp/2026/03/27/HK3S-0005--enable-vault-keycloak-oidc-operator-login-on-k3s/index.md
      Note: Current K3s Vault OIDC ticket that depends on the external Keycloak control plane
    - Path: ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/index.md
      Note: Shared cluster PostgreSQL is now live and should be the default backing-store candidate for any future Keycloak-on-K3s deployment
ExternalSources: []
Summary: "Implementation ticket for moving shared Keycloak onto K3s under Argo CD; the parallel in-cluster deployment, `infra` realm recreation, Vault login validation, and backup/restore smoke test are now complete, while final external cutover remains intentionally deferred."
LastUpdated: 2026-03-28T17:31:03-04:00
WhatFor: "Use this ticket to plan the future move of the shared Keycloak control plane from the external deployment at auth.scapegoat.dev onto the K3s cluster under Argo CD."
WhenToUse: "Read this when the Vault, Secrets Operator, and first-app migration tickets are stable enough to consider consolidating the shared identity plane onto K3s."
---

# Move shared Keycloak onto K3s under Argo CD

## Overview

This ticket is now in active implementation. The current operating model is still to keep the shared external Keycloak deployment online as the rollback path while the new in-cluster Keycloak is brought up behind a parallel hostname.

When this ticket is eventually executed, it should leave behind:

- a repo-managed Keycloak deployment on K3s
- a persistence and backup model suitable for realm, user, and client data
- a migration plan for the shared `infra` realm and later application realms
- a clear break-glass and rollback story if the in-cluster identity plane fails

## Current Step

Step 5 is complete for the `infra` realm slice: the parallel in-cluster deployment at `auth.yolo.scapegoat.dev` is live, the `infra` realm and `vault-oidc` client have been recreated against it, Vault operator login works against the new issuer, the realm-backed Account Console login works, and a logical PostgreSQL dump/restore smoke test has passed. The next decision is organizational, not technical: whether to start migrating non-`infra` application realms and when, if ever, to cut over `auth.scapegoat.dev`.

## Key Links

- Implementation plan:
  - [01-keycloak-on-k3s-plan.md](./playbooks/01-keycloak-on-k3s-plan.md)
- Implementation design:
  - [01-keycloak-on-k3s-implementation-design.md](./design-doc/01-keycloak-on-k3s-implementation-design.md)
- Implementation diary:
  - [01-keycloak-on-k3s-diary.md](./reference/01-keycloak-on-k3s-diary.md)

## Status

Current status: **active**

## Current Decision

Current decision:

- keep `auth.scapegoat.dev` external for now
- move Keycloak onto the current single-node K3s cluster as a parallel-host rollout
- when this ticket is activated, prefer shared in-cluster PostgreSQL as the Keycloak backing store instead of inventing a separate one-off database path
- use repo-owned manifests plus a Vault-backed PostgreSQL bootstrap `Job` rather than Terraform or an external chart to create the `keycloak` database contract
- keep non-`infra` realm migration and the final `auth.scapegoat.dev` cutover as a separate follow-on step after the parallel infra slice has proven itself

Why:

- Vault, Argo CD, and the first migrated apps already depend on this cluster
- shared PostgreSQL now exists on-cluster, so the data-store question is no longer open
- repo-owned manifests fit the current operational style of the cluster better than a vendor chart
- keeping the external Keycloak online preserves the rollback and break-glass path during the parallel rollout
- the parallel infra slice is now strong enough to prove the architecture without forcing an early hostname takeover

## Topics

- vault
- k3s
- infra
- gitops
- migration

## Tasks

See [tasks.md](./tasks.md) for the current task list.

## Changelog

See [changelog.md](./changelog.md) for recent changes and decisions.

## Structure

- design/ - Architecture and design documents
- reference/ - Prompt packs, API contracts, context summaries
- playbooks/ - Command sequences and test procedures
- scripts/ - Temporary code and tooling
- various/ - Working notes and research
- archive/ - Deprecated or reference-only artifacts

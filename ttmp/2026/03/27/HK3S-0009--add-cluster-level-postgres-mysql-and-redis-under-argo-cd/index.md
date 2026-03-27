---
Title: Add cluster-level Postgres MySQL and Redis under Argo CD
Ticket: HK3S-0009
Status: active
Topics:
    - k3s
    - infra
    - gitops
    - migration
DocType: index
Intent: long-term
Owners: []
RelatedFiles:
    - Path: gitops/kustomize/demo-stack/postgres-statefulset.yaml
      Note: Current per-app Postgres deployment that shows the existing baseline data-service pattern in this repo
    - Path: gitops/kustomize/demo-stack/postgres-service.yaml
      Note: Current per-app Postgres service wiring in the live demo stack
    - Path: ttmp/2026/03/27/HK3S-0006--deploy-vault-secrets-operator-on-k3s-and-prove-secret-sync/index.md
      Note: Secret-delivery dependency for any cluster-level service credentials
    - Path: ttmp/2026/03/27/HK3S-0007--recreate-the-first-application-on-k3s-using-vault-managed-secrets/index.md
      Note: First app-migration ticket that will eventually consume shared services
ExternalSources: []
Summary: "MySQL-first implementation ticket for introducing the first shared cluster data service under Argo CD so CoinVault and later applications can consume a stable in-cluster MySQL endpoint."
LastUpdated: 2026-03-27T16:34:00-04:00
WhatFor: "Use this ticket to implement the first shared cluster data-service slice on K3s, starting with MySQL because it is the active blocker for the CoinVault migration."
WhenToUse: "Read this when an application migration needs a stable in-cluster MySQL endpoint and the Vault/VSO path is already available."
---

# Add cluster-level Postgres MySQL and Redis under Argo CD

## Overview

This started as a deferred platform ticket for introducing reusable cluster-level data services on K3s:

- PostgreSQL
- MySQL
- Redis

The current repo only has an app-local PostgreSQL pattern in the demo stack. That is fine for the first migration slices, but it is not the eventual platform shape if multiple applications are going to land on this cluster and consume shared stateful infrastructure in a controlled way.

This ticket exists so that later work does not have to rediscover the design questions from scratch. When it is eventually executed, it should leave behind:

- repo-managed Argo CD applications for the chosen Postgres, MySQL, and Redis runtimes
- a clear decision on operator/chart/manifest packaging
- secret delivery through Vault-compatible patterns
- backup, restore, and upgrade guidance
- a consumption model for later applications

## Current Step

Step 5 is active: the repo-managed Kustomize MySQL deployment is live and validated. The next step is to use it from the blocked application-migration ticket.

## Key Links

- Implementation plan:
  - [01-cluster-data-services-plan.md](./playbooks/01-cluster-data-services-plan.md)
- MySQL-first design:
  - [01-mysql-first-cluster-data-services-design.md](./design-doc/01-mysql-first-cluster-data-services-design.md)
- Implementation diary:
  - [01-cluster-data-services-implementation-diary.md](./reference/01-cluster-data-services-implementation-diary.md)

## Status

Current status: **active**

## Current Decision

Current decision:

- implement MySQL now as the first shared cluster data service
- continue deferring PostgreSQL and Redis until after the first shared-service pattern is proven
- keep MySQL on repo-managed Kustomize manifests instead of the external Bitnami chart

Why:

- CoinVault is blocked on a MySQL host that only exists inside Coolify networking
- MySQL is the smallest cluster data-service slice that solves a real migration blocker today
- proving one shared data-service pattern first is still better than building all three at once
- the external Bitnami chart path proved brittle during live rollout, while repo-managed manifests gave a stable and reviewable operational surface

## Topics

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

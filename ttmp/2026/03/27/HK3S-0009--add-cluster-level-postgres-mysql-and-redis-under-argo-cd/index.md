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
    - Path: gitops/kustomize/postgres/statefulset.yaml
      Note: Live shared PostgreSQL StatefulSet that now defines the cluster-level Postgres baseline in this repo
    - Path: gitops/kustomize/postgres/service.yaml
      Note: Live shared PostgreSQL service wiring for the cluster-level Postgres endpoint
    - Path: ttmp/2026/03/27/HK3S-0006--deploy-vault-secrets-operator-on-k3s-and-prove-secret-sync/index.md
      Note: Secret-delivery dependency for any cluster-level service credentials
    - Path: ttmp/2026/03/27/HK3S-0007--recreate-the-first-application-on-k3s-using-vault-managed-secrets/index.md
      Note: First app-migration ticket that will eventually consume shared services
ExternalSources: []
Summary: "Implementation ticket for shared cluster data services under Argo CD; MySQL, PostgreSQL, and Redis are live, off-cluster backups and scratch restore drills now work, and the remaining follow-up is upgrade/rollback guidance plus one PostgreSQL data-integrity finding from the Draft Review dump."
LastUpdated: 2026-03-29T17:25:00-04:00
WhatFor: "Use this ticket to implement shared MySQL, PostgreSQL, and Redis service slices on K3s using the platform's repo-managed manifest and Vault/VSO patterns."
WhenToUse: "Read this when the platform needs stable in-cluster MySQL, PostgreSQL, or Redis endpoints and the Vault/VSO path is already available."
---

# Add cluster-level Postgres MySQL and Redis under Argo CD

## Overview

This started as a deferred platform ticket for introducing reusable cluster-level data services on K3s:

- PostgreSQL
- MySQL
- Redis

The current repo only has an app-local PostgreSQL pattern in the demo stack. That is fine for the first migration slices, but it is not the eventual platform shape if multiple applications are going to land on this cluster and consume shared stateful infrastructure in a controlled way.

This ticket exists so that later work does not have to rediscover the design questions from scratch. The service rollout, backup jobs, and scratch restore drills are now implemented. The remaining work is operational hardening around upgrade/rollback guidance and one restore-drill finding in the Draft Review PostgreSQL data.

When it is eventually closed, it should leave behind:

- repo-managed Argo CD applications for the chosen Postgres, MySQL, and Redis runtimes
- a clear decision on operator/chart/manifest packaging
- secret delivery through Vault-compatible patterns
- backup, restore, and upgrade guidance
- a consumption model for later applications

## Current Step

Step 11 is active: scheduled off-cluster backups and scratch restore drills for PostgreSQL, MySQL, and Redis are complete, and the remaining work in this ticket is explicit upgrade and rollback procedures plus follow-up on the orphaned Draft Review foreign-key references exposed by the PostgreSQL restore replay.

## Key Links

- Implementation plan:
  - [01-cluster-data-services-plan.md](./playbooks/01-cluster-data-services-plan.md)
- Backup and restore plan:
  - [02-cluster-data-services-backup-and-restore-plan.md](./playbooks/02-cluster-data-services-backup-and-restore-plan.md)
- MySQL-first design:
  - [01-mysql-first-cluster-data-services-design.md](./design-doc/01-mysql-first-cluster-data-services-design.md)
- Postgres and Redis follow-on design:
  - [02-postgres-and-redis-cluster-services-design.md](./design-doc/02-postgres-and-redis-cluster-services-design.md)
- Implementation diary:
  - [01-cluster-data-services-implementation-diary.md](./reference/01-cluster-data-services-implementation-diary.md)

## Status

Current status: **active**

## Current Decision

Current decision:

- implement MySQL now as the first shared cluster data service
- use the now-proven shared-service pattern to add PostgreSQL and Redis next, which is now done
- keep MySQL on repo-managed Kustomize manifests instead of the external Bitnami chart
- store data-service backups in a shared Hetzner Object Storage bucket reached through Vault/VSO-delivered runtime credentials

Why:

- CoinVault is blocked on a MySQL host that only exists inside Coolify networking
- MySQL is the smallest cluster data-service slice that solves a real migration blocker today
- proving one shared data-service pattern first is still better than building all three at once
- the external Bitnami chart path proved brittle during live rollout, while repo-managed manifests gave a stable and reviewable operational surface
- that same repo-managed manifest path successfully brought up shared PostgreSQL and Redis too
- a single off-cluster object-storage target is the simplest operational baseline for this single-node cluster, and the live backup jobs now prove that path end to end
- the scratch restore drills now prove the object-storage artifacts are usable in practice, while also surfacing a real Draft Review data-integrity issue that should be cleaned up before relying on the PostgreSQL dump for full disaster recovery

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

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
Summary: "Deferred platform ticket for introducing cluster-level Postgres, MySQL, and Redis deployments under Argo CD so later applications can consume shared data services on K3s."
LastUpdated: 2026-03-27T14:20:00-04:00
WhatFor: "Use this ticket to plan the future introduction of cluster-level Postgres, MySQL, and Redis on K3s under GitOps management."
WhenToUse: "Read this when the base secrets path and first app migrations are stable enough that it makes sense to centralize stateful data services instead of continuing with per-app databases."
---

# Add cluster-level Postgres MySQL and Redis under Argo CD

## Overview

This is a deferred platform ticket for introducing reusable cluster-level data services on K3s:

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

Deferred follow-up. Do not implement shared cluster databases yet; first finish the Vault Secrets Operator and at least one real application migration.

## Key Links

- Implementation plan:
  - [01-cluster-data-services-plan.md](./playbooks/01-cluster-data-services-plan.md)

## Status

Current status: **active**

## Deferred Decision

Current decision:

- do not add shared cluster Postgres, MySQL, or Redis yet
- keep using the current app-local Postgres pattern where needed during the first migration slices

Why:

- the current migration priority is secrets delivery and first-application recreation
- shared stateful services introduce storage, upgrade, backup, and multi-tenant design questions that are not required to prove the first platform path
- it is better to centralize data services after at least one real app has clarified the actual consumption pattern

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

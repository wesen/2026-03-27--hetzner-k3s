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
Summary: Design record for implementing shared MySQL first on K3s, leaving PostgreSQL and Redis for later slices.
LastUpdated: 2026-03-27T15:15:00-04:00
WhatFor: Explain why MySQL is being implemented first, which packaging model it uses, and how Vault/VSO should deliver credentials into the chart.
WhenToUse: Read this before scaffolding or reviewing the shared MySQL deployment.
---

# MySQL-first cluster data services design

## Executive Summary

We should implement MySQL first, not all three planned data services. CoinVault exposed an immediate need for a stable in-cluster MySQL endpoint because its current host is a Coolify-internal alias that K3s cannot resolve. The cleanest first slice is a shared MySQL deployment under Argo CD using the Bitnami MySQL chart, with credentials delivered from Vault through VSO into the chart’s `auth.existingSecret` contract.

## Problem Statement

The original ticket grouped PostgreSQL, MySQL, and Redis into one later platform phase. That broad framing is no longer ideal. We now have a concrete blocker:

- CoinVault expects MySQL
- its current MySQL host only exists inside Coolify networking
- K3s cannot use that host

So we need one shared MySQL service now, not a speculative multi-database platform build.

## Proposed Solution

Implement one Argo CD-managed MySQL deployment with these properties:

- namespace: `mysql`
- packaging: Bitnami MySQL chart
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

### Decision 2: Use the Bitnami chart instead of writing raw StatefulSet manifests

The official Bitnami chart already provides:

- persistence handling
- authentication bootstrapping
- service wiring
- health probes
- upgrade surface that is better documented than a hand-rolled StatefulSet

The current chart metadata from the official sources shows:

- chart version `14.0.5`
- app version `9.4.0`

### Decision 3: Use `auth.existingSecret` with VSO

The chart’s official `values.yaml` documents `auth.existingSecret` and the required secret keys. That is a good fit for VSO because:

- Vault remains the secret source of truth
- Kubernetes still gets a native `Secret`
- the chart consumes a normal Kubernetes interface

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

### Alternative 3: Hand-write a raw StatefulSet and Secret

Rejected because the chart already encodes the basic operational contract and supports the secret interface we want.

## Implementation Plan

1. Add the MySQL-first design and diary artifacts.
2. Add a Vault Kubernetes-auth policy and role for the MySQL service account.
3. Add an Argo CD application for the Bitnami MySQL chart.
4. Configure the chart to consume a VSO-managed `mysql-auth` secret.
5. Add helper scripts to seed Vault and validate the deployment.
6. Deploy and validate the shared MySQL instance.
7. Update CoinVault to consume the in-cluster MySQL host.

## Open Questions

- Should the first CoinVault database/user be created by chart defaults or by an explicit init script?
- Do we want metrics enabled in the first slice, or only after the service is stable?
- When we later add Postgres, should it copy the same chart-plus-VSO pattern or use an operator?

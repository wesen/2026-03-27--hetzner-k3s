---
Title: Shared Postgres and Redis cluster services design
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
      Note: Existing repo-owned Postgres baseline to mirror for a shared service
    - Path: gitops/kustomize/mysql/statefulset.yaml
      Note: Proven shared-service shape already live for MySQL
    - Path: ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/design-doc/01-mysql-first-cluster-data-services-design.md
      Note: The first shared-service design record that established the repo-owned manifest pattern
ExternalSources: []
Summary: Design record for extending HK3S-0009 beyond MySQL by adding shared PostgreSQL and Redis using the same repo-managed Kustomize and Vault/VSO pattern.
LastUpdated: 2026-03-28T15:15:00-04:00
WhatFor: Explain why shared PostgreSQL and Redis should follow the MySQL pattern and what the initial runtime shape should be.
WhenToUse: Read this before scaffolding or reviewing the shared PostgreSQL and Redis deployments.
---

# Shared Postgres and Redis cluster services design

## Executive Summary

PostgreSQL and Redis should now be added as shared cluster services under Argo CD using the same pattern that was proven with MySQL:

- repo-owned Kustomize manifests
- dedicated namespace per service
- Vault-authenticated service account
- VSO-synced Kubernetes secret
- single-replica StatefulSet with `local-path` persistence

This keeps the platform consistent. The current repo already has an app-local Postgres baseline and a live shared MySQL deployment. Redis is new, but its operational shape is still simple enough to fit the same model.

## Problem Statement

HK3S-0009 started as an umbrella ticket. MySQL became the first concrete implementation because CoinVault needed it immediately. That left the original broader platform goal only partially satisfied. If multiple applications are going to move onto this cluster, the remaining shared data-service gaps are:

- no shared PostgreSQL service for apps that should not use the demo-stack-local instance
- no shared Redis service for caches, queues, or ephemeral coordination

We now have enough platform evidence to implement the remaining two services without guessing from scratch.

## Proposed Solution

Implement two additional Argo CD applications:

- `postgres`
- `redis`

Each service should follow the same boundary model:

- namespace owns the runtime
- Vault path stores generated credentials and service discovery data
- VSO projects those values into a Kubernetes `Secret`
- StatefulSet consumes the Kubernetes `Secret`
- a normal ClusterIP service gives applications a stable in-cluster hostname

### Shared PostgreSQL shape

- namespace: `postgres`
- service: `postgres.postgres.svc.cluster.local:5432`
- image: `postgres:16-alpine`
- secret path: `kv/infra/postgres/cluster`
- initial database: `platform`
- initial user: `platform_admin`

### Shared Redis shape

- namespace: `redis`
- service: `redis.redis.svc.cluster.local:6379`
- image: `redis:7-alpine`
- auth mode: password protected via `requirepass`
- persistence: append-only file on a retained PVC
- secret path: `kv/infra/redis/cluster`

## Design Decisions

### Decision 1: Reuse the MySQL platform pattern

This is the main consistency decision. MySQL is already live and proved:

- the Vault auth model
- the VSO projection model
- the repo-owned Kustomize model
- the “single namespace, single service” operator workflow

So Postgres and Redis should not introduce operators or chart dependencies unless a concrete requirement appears.

### Decision 2: Use dedicated namespaces and applications

Each service remains independently observable and independently replaceable. This keeps Argo state, pod logs, service discovery, and credentials simple.

### Decision 3: Keep the first slice single-replica and non-HA

The cluster itself is still single-node. Pretending the data tier is HA would only make the manifests more complex without changing the actual failure boundary.

### Decision 4: Make Redis persistent

Redis can be run as pure cache or as durable state. For this platform slice, the safer default is to enable AOF persistence so restart behavior can be validated and future uses are not constrained to “cache only.”

## Alternatives Considered

### Alternative 1: Keep using only app-local Postgres and no shared Redis

Rejected because it leaves the platform incomplete and forces every future app migration to rediscover whether it should invent a one-off runtime or wait for the shared service later.

### Alternative 2: Use operators for Postgres and Redis immediately

Rejected because the single-node cluster and current operational scale do not justify the extra controllers yet.

### Alternative 3: Bundle Postgres and Redis into one namespace or one Argo application

Rejected because it weakens service boundaries and makes later debugging noisier.

## Implementation Plan

1. Update HK3S-0009 tasks and docs to reactivate the Postgres and Redis slices.
2. Add Vault policies and Kubernetes roles for `postgres` and `redis`.
3. Add bootstrap scripts to seed Vault secret paths for each service.
4. Add Argo applications and Kustomize manifests for each service.
5. Apply the Vault bootstrap and secret-seeding steps.
6. Deploy PostgreSQL and validate SQL access plus restart behavior.
7. Deploy Redis and validate auth plus persistence across restart.
8. Update the ticket diary, changelog, and plan with the live outcomes.

## Open Questions

- Should PostgreSQL later gain per-app database bootstrap helpers the same way MySQL effectively has a first-tenant contract?
- Should Redis remain a single shared logical database for now, or should we formalize DB-number allocation for apps?

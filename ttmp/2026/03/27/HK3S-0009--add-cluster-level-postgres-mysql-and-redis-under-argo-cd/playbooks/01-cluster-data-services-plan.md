---
Title: Cluster data services deferred implementation plan
Ticket: HK3S-0009
Status: active
Topics:
    - k3s
    - infra
    - gitops
    - migration
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../gitops/kustomize/demo-stack/postgres-statefulset.yaml
      Note: Current app-local PostgreSQL baseline in the live repo
    - Path: ../../../../../../gitops/kustomize/demo-stack/postgres-service.yaml
      Note: Current service exposure pattern for app-local PostgreSQL
    - Path: ../../HK3S-0006--deploy-vault-secrets-operator-on-k3s-and-prove-secret-sync/index.md
      Note: Secret-delivery prerequisite for shared service credentials
    - Path: ../../HK3S-0007--recreate-the-first-application-on-k3s-using-vault-managed-secrets/index.md
      Note: First app-migration consumer that should inform the eventual shared-service design
ExternalSources: []
Summary: "Deferred plan for later introducing shared Postgres, MySQL, and Redis services on K3s under Argo CD."
LastUpdated: 2026-03-27T14:20:00-04:00
WhatFor: "Use this to remember the intended sequencing and design questions for shared cluster data services."
WhenToUse: "Read this after the secrets path and first-app migration are stable enough to justify shared stateful infrastructure."
---

# Cluster data services deferred implementation plan

## Purpose

Capture the later-phase plan for adding shared PostgreSQL, MySQL, and Redis services to the K3s cluster under Argo CD, but explicitly defer that move until the current secrets and first-application migration work is stable.

## Current recommendation

Do not implement this yet.

Keep the current simpler pattern for now because:

- the repo already has a working app-local PostgreSQL example
- shared stateful services add storage, backup, and multi-tenant complexity
- the right platform shape should be informed by at least one real migrated application, not guessed in advance

## Trigger to revisit this ticket

Revisit when all of the following are true:

- Vault Secrets Operator or another stable secret-delivery path is proven
- at least one real application is running on K3s
- the team knows whether multiple apps actually need shared Postgres, MySQL, Redis, or only one or two of them
- the cluster storage and backup story is strong enough for shared stateful services

## Recommended sequence

1. Choose one service first, probably PostgreSQL, because the repo already has a local baseline for it.
2. Prove the shared-service pattern end to end:
   provision, credentials, backup, restore, app consumption.
3. Only then decide whether MySQL and Redis should be introduced as platform services too.

That avoids turning this into a three-database platform project before the first one is even proven.

## Main design questions

- Should these be shared platform services at all, or should some apps keep app-local instances?
- Should PostgreSQL and MySQL use operators or simpler charts?
- Should Redis be treated as durable state, cache, queue, or all three?
- How should credentials be generated, rotated, and delivered from Vault?
- What is the namespace and network-policy boundary for multi-app access?

## Existing anchors in this repo

- Current app-local PostgreSQL manifests:
  - [postgres-statefulset.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/demo-stack/postgres-statefulset.yaml)
  - [postgres-service.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/demo-stack/postgres-service.yaml)
- Current Argo CD/Kustomize operator docs:
  - [docs/argocd-app-setup.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/argocd-app-setup.md)
- Current secrets-path dependency:
  - [HK3S-0006 index](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0006--deploy-vault-secrets-operator-on-k3s-and-prove-secret-sync/index.md)

## Acceptance criteria for the future implementation

- the selected shared data service is GitOps-managed under Argo CD
- backups and restore are tested
- at least one application consumes the service successfully
- credential delivery is Vault-compatible and documented
- engine upgrades and rollback procedures are documented

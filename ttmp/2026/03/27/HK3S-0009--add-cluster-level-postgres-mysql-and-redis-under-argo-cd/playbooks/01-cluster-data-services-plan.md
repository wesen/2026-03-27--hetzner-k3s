---
Title: Cluster data services implementation plan
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
Summary: "Implementation plan for shared Postgres, MySQL, and Redis services on K3s under Argo CD, now that MySQL is proven and the remaining slices are being executed."
LastUpdated: 2026-03-28T15:15:00-04:00
WhatFor: "Use this to understand the intended sequencing, implementation pattern, and acceptance criteria for the shared cluster data services."
WhenToUse: "Read this when continuing HK3S-0009 or reviewing why Postgres and Redis follow the same repo-owned manifest path as MySQL."
---

# Cluster data services implementation plan

## Purpose

Capture the implementation plan for adding shared PostgreSQL, MySQL, and Redis services to the K3s cluster under Argo CD.

## Current recommendation

Implement the remaining shared-service slices using the MySQL pattern that is already live:

- repo-owned Kustomize manifests
- Argo CD `Application` per service
- Vault plus VSO for credentials
- single-replica retained-persistence StatefulSet

## Current trigger state

The original trigger conditions are now satisfied:

- Vault/VSO is proven
- real applications are running on K3s
- MySQL is already implemented and live
- the repo-owned manifest model has proven more stable than the external chart path

## Recommended sequence

1. Keep MySQL as the proven anchor service.
2. Add shared PostgreSQL next, because the repo already has an app-local baseline and the service model is close to MySQL.
3. Add shared Redis after that, using the same Vault/VSO plus Kustomize pattern.
4. Once all three exist, revisit backup/restore and upgrade procedures as a combined platform concern.

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
- Current shared MySQL manifests:
  - [statefulset.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/mysql/statefulset.yaml)
  - [vault-static-secret.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/mysql/vault-static-secret.yaml)
- Current Argo CD/Kustomize operator docs:
  - [docs/argocd-app-setup.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/argocd-app-setup.md)
- Current secrets-path dependency:
  - [HK3S-0006 index](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0006--deploy-vault-secrets-operator-on-k3s-and-prove-secret-sync/index.md)

## Acceptance criteria for the implementation

- the selected shared data service is GitOps-managed under Argo CD
- backups and restore are tested
- at least one application consumes the service successfully
- credential delivery is Vault-compatible and documented
- engine upgrades and rollback procedures are documented

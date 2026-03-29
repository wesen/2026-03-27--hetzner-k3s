---
Title: Implement Vault snapshots and Hetzner server backups
Ticket: HK3S-0017
Status: active
Topics:
    - k3s
    - vault
    - backup
    - restore
    - hetzner
    - terraform
    - disaster-recovery
DocType: index
Intent: long-term
Owners: []
RelatedFiles:
    - Path: gitops/applications/vault.yaml
      Note: Live Vault deployment that needs an off-cluster snapshot path
    - Path: main.tf
      Note: Hetzner server resource that should own automatic server backups
    - Path: ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/index.md
      Note: Existing shared data-service backup work that this ticket should align with
ExternalSources: []
Summary: "Implement the two missing recovery layers for this cluster: Vault Raft snapshots uploaded off-cluster and Hetzner automatic server backups for coarse full-node recovery."
LastUpdated: 2026-03-29T18:10:00-04:00
WhatFor: "Use this ticket to add real backup coverage for Vault itself and the full Hetzner node."
WhenToUse: "Read this when extending or reviewing the disaster-recovery posture of the single-node K3s platform."
---

# Implement Vault snapshots and Hetzner server backups

## Overview

This ticket exists because the cluster now has application-data backups, but it still has two important recovery gaps:

- Vault itself does not yet have an off-cluster snapshot pipeline.
- The Hetzner node does not yet have provider-level automatic backups enabled.

Those two layers solve different problems:

- Vault Raft snapshots protect the secrets and auth control plane in a structured, service-specific way.
- Hetzner automatic Backups protect the coarse whole-node state so recovery is not limited to rebuilding from scratch under time pressure.

The goal of this ticket is to implement both in a way that matches the rest of the platform:

- Terraform owns Hetzner infrastructure settings.
- GitOps owns cluster jobs and runtime behavior.
- Vault and VSO own runtime credentials.
- replayable operator scripts live under the ticket `scripts/` directory.

## Current Step

Step 1 is active: define the implementation contract and add the actual rollout tasks before touching Terraform or the live cluster.

## Key Links

- Design guide:
  - [01-vault-snapshot-and-server-backup-strategy.md](./design-doc/01-vault-snapshot-and-server-backup-strategy.md)
- Implementation guide:
  - [01-vault-snapshot-and-server-backup-implementation-guide.md](./playbooks/01-vault-snapshot-and-server-backup-implementation-guide.md)
- Implementation diary:
  - [01-vault-snapshot-and-server-backup-diary.md](./reference/01-vault-snapshot-and-server-backup-diary.md)

## Current Decision

Current decision:

- use Hetzner automatic server Backups on the `hcloud_server` resource for coarse full-node recovery
- use a Vault OSS-compatible Raft snapshot CronJob for service-level Vault backups
- upload Vault snapshots into the existing Hetzner Object Storage backup bucket under a dedicated `vault/` prefix
- reuse the platform Vault/VSO object-storage secret-delivery path rather than inventing a second secret model
- authenticate the Vault snapshot job through the existing Vault Kubernetes auth backend rather than storing a root token in Kubernetes

Why:

- Hetzner Backups and Vault snapshots solve different recovery problems and should both exist
- VM-level backups are not enough for disciplined Vault recovery
- Vault OSS does not give us enterprise auto-snapshots, so we need a repo-owned CronJob
- the platform already has a proven off-cluster object-storage path from HK3S-0009

## Tasks

See [tasks.md](./tasks.md) for the live implementation checklist.

## Changelog

See [changelog.md](./changelog.md) for the chronological change trail.

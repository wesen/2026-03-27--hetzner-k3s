---
Title: Design Vault on K3s and GitOps Migration Plan
Ticket: HK3S-0002
Status: active
Topics:
    - vault
    - k3s
    - argocd
    - gitops
    - terraform
    - migration
DocType: index
Intent: long-term
Owners: []
RelatedFiles:
    - Path: cloud-init.yaml.tftpl
      Note: Current cluster bootstrap boundary showing why Vault belongs in day-two GitOps state
    - Path: gitops/applications/demo-stack.yaml
      Note: Reference Argo application pattern already working in the cluster repo
ExternalSources: []
Summary: Research ticket for moving Vault from the current Coolify deployment onto the Hetzner K3s cluster and establishing the long-term secret delivery model for later app migrations.
LastUpdated: 2026-03-27T11:26:00-04:00
WhatFor: Use this as the entrypoint for the Vault-on-K3s migration research, design, and follow-up implementation planning.
WhenToUse: Read this first when resuming the ticket or reviewing what documents were produced and why.
---



# Design Vault on K3s and GitOps Migration Plan

## Overview

This ticket analyzes how to move the current Vault setup away from Coolify and onto the Hetzner K3s cluster, then use that new Vault deployment as the secret-management foundation for later application migrations. The design is evidence-backed from the current Terraform repo, the current CoinVault and hair-booking patterns, the live K3s environment, and the previous deployment diaries.

The deliverables are deliberately split into:

- a long-form design doc,
- a chronological research diary,
- and an operator-oriented migration playbook.

## Current Step

Research, validation, and publication are complete. The next step is to open the first implementation ticket for deploying Vault into K3s.

## Key Links

- Design doc:
  - [01-vault-on-k3s-and-gitops-migration-design.md](./design-doc/01-vault-on-k3s-and-gitops-migration-design.md)
- Diary:
  - [01-investigation-diary.md](./reference/01-investigation-diary.md)
- Playbook:
  - [01-vault-on-k3s-migration-playbook.md](./playbook/01-vault-on-k3s-migration-playbook.md)

## Status

Current status: **active**

## Topics

- vault
- k3s
- argocd
- gitops
- terraform
- migration

## Key Findings

- Current Vault is healthy but still controlled through Coolify-specific host automation.
- Current app secret paths are already good and should be preserved.
- The K3s cluster is healthy, GitOps-managed, and has enough capacity for a single-node Vault plus a secret-sync controller.
- The best default in-cluster secret consumption model is Kubernetes auth plus Vault Secrets Operator, not AppRole for every workload.
- The best migration shape is a parallel K3s Vault hostname first, not an in-place replacement of the current Coolify Vault endpoint.

## Tasks

See [tasks.md](./tasks.md) for the current task list.

## Changelog

See [changelog.md](./changelog.md) for recent changes and decisions.

## Structure

- design-doc/ - architecture and migration design
- reference/ - research diary and detailed evidence trail
- playbook/ - ordered operator implementation sequence
- scripts/ - reserved for any ticket-local automation if needed later
- various/ - reserved for overflow notes or imported sources if needed later

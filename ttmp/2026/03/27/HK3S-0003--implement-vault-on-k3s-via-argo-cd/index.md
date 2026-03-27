---
Title: Implement Vault on K3s via Argo CD
Ticket: HK3S-0003
Status: complete
Topics:
    - vault
    - k3s
    - argocd
    - gitops
    - migration
DocType: index
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: "Implementation ticket for recreating Vault on the Hetzner K3s cluster via Argo CD, starting with the deployment scaffold and live bring-up rather than Coolify cutover."
LastUpdated: 2026-03-27T13:19:00-04:00
WhatFor: "Use this as the execution ticket for the first concrete Vault-on-K3s implementation work."
WhenToUse: "Read this when carrying out the K3s Vault deployment tasks or reviewing what has been completed so far."
---

# Implement Vault on K3s via Argo CD

## Overview

This ticket turns the prior research/design work into actual implementation. The scope is intentionally narrower than a full migration: recreate Vault on the K3s platform first, keep the existing Coolify Vault alive, and avoid cutover work until the K3s deployment is healthy and reviewable.

The immediate goal is to get a repo-managed Argo CD application plus the minimal non-git bootstrap needed for AWS KMS auto-unseal, then deploy and validate the new Vault instance at `vault.yolo.scapegoat.dev`.

## Current Step

Completed: the K3s Vault deployment is live, initialized, stored off-cluster in 1Password, and verified to auto-unseal after a forced restart.

## Key Links

- Research ticket:
  - [HK3S-0002 design index](../HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/index.md)
- Implementation playbook:
  - [01-vault-on-k3s-implementation-plan.md](./playbook/01-vault-on-k3s-implementation-plan.md)
- Implementation diary:
  - [01-implementation-diary.md](./reference/01-implementation-diary.md)

## Status

Current status: **complete**

## Result

The K3s-hosted Vault instance is now live and healthy:

- Argo CD application: `vault`
- Hostname: `vault.yolo.scapegoat.dev`
- Storage: single-node Raft on `local-path`
- TLS: Traefik ingress with cert-manager certificate
- Seal: AWS KMS auto-unseal using `alias/vault-scapegoat-dev-unseal`
- Recovery material: stored outside git and outside the server in a 1Password secure note

## Next Tickets

Recommended next implementation tickets:

- Enable Vault human login through Keycloak OIDC on `vault.yolo.scapegoat.dev`
- Enable Vault Kubernetes auth and bootstrap baseline policies and roles
- Deploy Vault Secrets Operator and prove secret sync in a non-production namespace
- Recreate the first application deployment on K3s using Vault-managed secrets rather than `.envrc` or semi-manual operator flows

## Topics

- vault
- k3s
- argocd
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

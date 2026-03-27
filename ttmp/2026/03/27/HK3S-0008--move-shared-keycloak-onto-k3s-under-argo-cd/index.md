---
Title: Move shared Keycloak onto K3s under Argo CD
Ticket: HK3S-0008
Status: active
Topics:
    - vault
    - k3s
    - infra
    - gitops
    - migration
DocType: index
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ttmp/2026/03/27/HK3S-0005--enable-vault-keycloak-oidc-operator-login-on-k3s/index.md
      Note: Current K3s Vault OIDC ticket that depends on the external Keycloak control plane
ExternalSources: []
Summary: "Deferred follow-up ticket for eventually moving the shared Keycloak control plane from the external deployment to K3s under Argo CD."
LastUpdated: 2026-03-27T14:15:00-04:00
WhatFor: "Use this ticket to plan the future move of the shared Keycloak control plane from the external deployment at auth.scapegoat.dev onto the K3s cluster under Argo CD."
WhenToUse: "Read this when the Vault, Secrets Operator, and first-app migration tickets are stable enough to consider consolidating the shared identity plane onto K3s."
---

# Move shared Keycloak onto K3s under Argo CD

## Overview

This is a deferred platform ticket. The current decision is to keep the shared Keycloak deployment external for now, even though Vault now runs on K3s, because external Keycloak still provides a cleaner recovery and break-glass control plane while the rest of the platform migration is still in motion.

The goal of this ticket is not to start implementation immediately. The goal is to preserve the design and execution outline for a later phase where the shared Keycloak control plane can be moved onto K3s and managed under Argo CD without losing login continuity for Vault and application users.

When this ticket is eventually executed, it should leave behind:

- a repo-managed Keycloak deployment on K3s
- a persistence and backup model suitable for realm, user, and client data
- a migration plan for the shared `infra` realm and later application realms
- a clear break-glass and rollback story if the in-cluster identity plane fails

## Current Step

Deferred follow-up. Keep the external Keycloak deployment for now and revisit this only after the Vault Secrets Operator and first migrated application tickets are stable.

## Key Links

- Implementation plan:
  - [01-keycloak-on-k3s-plan.md](./playbooks/01-keycloak-on-k3s-plan.md)

## Status

Current status: **active**

## Deferred Decision

Current decision:

- keep `auth.scapegoat.dev` external for now
- do not move Keycloak onto the single-node K3s cluster during the current Vault and first-app migration phase

Why:

- Vault, Argo CD, and the first migrated apps already depend on this cluster
- keeping Keycloak external preserves an out-of-cluster operator login path during cluster recovery
- identity-plane consolidation is valuable, but it is not on the critical path for the current secrets and application migration work

## Topics

- vault
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

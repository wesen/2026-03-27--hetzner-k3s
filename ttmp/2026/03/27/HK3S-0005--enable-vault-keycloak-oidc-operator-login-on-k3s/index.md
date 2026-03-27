---
Title: Enable Vault Keycloak OIDC operator login on K3s
Ticket: HK3S-0005
Status: complete
Topics:
    - vault
    - k3s
    - infra
DocType: index
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: ""
LastUpdated: 2026-03-27T14:10:00-04:00
WhatFor: "Use this ticket to recreate the human operator OIDC login path on the K3s-hosted Vault instance using Keycloak and the new Vault hostname."
WhenToUse: "Read this when implementing or reviewing the human operator authentication path into the K3s Vault."
---

# Enable Vault Keycloak OIDC operator login on K3s

## Overview

This ticket recreates the human operator login path for the K3s-hosted Vault instance. The older Coolify Vault already has a Keycloak-backed OIDC operator flow documented in the Terraform repo. The K3s Vault now has the same capability, pointed at `vault.yolo.scapegoat.dev`, while reusing the shared `infra` Keycloak realm and `vault-oidc` client instead of inventing a second operator identity model.

The ticket leaves behind:

- a shared Keycloak client configuration that allows the K3s Vault hostname
- a Vault `oidc/` auth mount and `operators` role on the K3s Vault instance
- policy and identity-group mappings for admins and read-only operators
- a clear operator playbook for UI and CLI login
- recorded validation for positive and negative login outcomes

## Current Step

Completed: the shared Keycloak client now allows `vault.yolo.scapegoat.dev`, Vault `oidc/` is configured on the K3s instance, the UI login reaches the dashboard for an `infra-admins` user, and CLI login succeeds for an allowed user while rejecting a user outside the operator groups.

## Key Links

- Implementation plan:
  - [01-vault-k3s-oidc-plan.md](./playbooks/01-vault-k3s-oidc-plan.md)
- Operator playbook:
  - [02-vault-k3s-oidc-operator-playbook.md](./playbooks/02-vault-k3s-oidc-operator-playbook.md)
- Implementation diary:
  - [01-vault-k3s-oidc-diary.md](./reference/01-vault-k3s-oidc-diary.md)

## Status

Current status: **complete**

## Result

The K3s Vault now supports human operator login through the shared Keycloak `infra` realm:

- auth mount: `oidc/`
- role: `operators`
- client: `vault-oidc`
- UI callback: `https://vault.yolo.scapegoat.dev/ui/vault/auth/oidc/oidc/callback`
- CLI callbacks:
  - `http://localhost:8250/oidc/callback`
  - `http://127.0.0.1:8250/oidc/callback`
- external identity groups:
  - `infra-admins` -> `admin`
  - `infra-readonly` -> `ops-readonly`

Validation passed for:

- browser login to the Vault dashboard as an `infra-admins` user
- CLI login via `vault login -method=oidc role=operators` returning the `admin` identity policy
- negative CLI login from a user outside the operator groups, rejected before token issuance

## Topics

- vault
- k3s
- infra

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

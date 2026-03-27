---
Title: Enable Vault Keycloak OIDC operator login on K3s
Ticket: HK3S-0005
Status: active
Topics:
    - vault
    - k3s
    - keycloak
    - oidc
    - security
DocType: index
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: ""
LastUpdated: 2026-03-27T13:28:09.433394062-04:00
WhatFor: "Use this ticket to recreate the human operator OIDC login path on the K3s-hosted Vault instance using Keycloak and the new Vault hostname."
WhenToUse: "Read this when implementing or reviewing the human operator authentication path into the K3s Vault."
---

# Enable Vault Keycloak OIDC operator login on K3s

## Overview

This ticket recreates the human operator login path for the K3s-hosted Vault instance. The older Coolify Vault already has a Keycloak-backed OIDC operator flow documented in the Terraform repo. The K3s Vault needs the same class of capability, but pointed at the new hostname `vault.yolo.scapegoat.dev` and wired in a way that does not rely on the old Vault deployment remaining authoritative.

The ticket should leave behind:

- a Keycloak client configuration aligned to the K3s Vault hostname
- a Vault `oidc/` auth mount and role for operators
- policy and identity-group mappings for admins and read-only operators
- a clear operator playbook for UI and CLI login

## Current Step

Planned next ticket. The analysis, plan, and task breakdown are ready; implementation has not started yet.

## Key Links

- Implementation plan:
  - [01-vault-k3s-oidc-plan.md](./playbooks/01-vault-k3s-oidc-plan.md)

## Status

Current status: **active**

## Topics

- vault
- k3s
- keycloak
- oidc
- security

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

---
Title: Recreate the first application on K3s using Vault managed secrets
Ticket: HK3S-0007
Status: active
Topics:
    - vault
    - k3s
    - migration
    - gitops
    - applications
DocType: index
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: "Implement the first real application deployment on K3s using Argo CD, Vault-managed secrets, and the VSO secret-delivery path."
LastUpdated: 2026-03-27T20:30:00-04:00
WhatFor: "Use this ticket to recreate the first real application deployment on K3s using Vault-managed secrets and the new GitOps platform path."
WhenToUse: "Read this when choosing and executing the first application migration after the platform secret path is ready."
---

# Recreate the first application on K3s using Vault managed secrets

## Overview

This ticket is the first application-facing migration after the Vault platform layers are in place. The goal is not a generic “move an app someday.” The goal is to choose one concrete application, recreate it on K3s, and ensure it receives secrets from Vault rather than from semi-manual host-local or Coolify-specific environment management.

The main design question in this ticket is which app should go first. CoinVault already has a rich Vault contract but also more moving parts. Hair-booking may be simpler operationally. The plan therefore includes an explicit decision step instead of pretending the first app is already chosen.

## Current Step

Step 7 is active: post-rollout runtime debugging is complete, the live pod now resolves `profile_registries=/run/secrets/pinocchio/profiles.yaml`, and the next step is handoff plus cutover planning against the existing Coolify deployment.

## Key Links

- Implementation plan:
  - [01-first-app-migration-plan.md](./playbooks/01-first-app-migration-plan.md)
- Candidate decision and runtime contract:
  - [01-first-app-candidate-decision-and-runtime-contract.md](./design-doc/01-first-app-candidate-decision-and-runtime-contract.md)
- Implementation diary:
  - [01-first-app-migration-diary.md](./reference/01-first-app-migration-diary.md)

## Status

Current status: **active**

## Topics

- vault
- k3s
- migration
- gitops
- applications

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

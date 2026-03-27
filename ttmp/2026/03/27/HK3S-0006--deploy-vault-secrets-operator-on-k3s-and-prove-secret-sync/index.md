---
Title: Deploy Vault Secrets Operator on K3s and prove secret sync
Ticket: HK3S-0006
Status: active
Topics:
    - vault
    - k3s
    - kubernetes
    - security
    - gitops
DocType: index
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: ""
LastUpdated: 2026-03-27T13:28:09.477768134-04:00
WhatFor: "Use this ticket to deploy Vault Secrets Operator on K3s and prove the first GitOps-friendly secret sync path from Vault into Kubernetes."
WhenToUse: "Read this when preparing the operator/controller layer that will bridge Vault secrets into Kubernetes-native objects."
---

# Deploy Vault Secrets Operator on K3s and prove secret sync

## Overview

This ticket adds Vault Secrets Operator (VSO) after the machine-auth foundation is in place. The goal is not merely to install another controller. The goal is to prove the full path from Vault secret -> VSO auth -> Kubernetes `Secret`, because that is the most likely consumption pattern for GitOps-managed applications on this cluster.

The ticket should leave behind:

- a repo-managed Argo CD application for VSO
- a working `VaultConnection` / `VaultAuth` configuration that uses the Kubernetes auth mount from `HK3S-0004`
- a non-production smoke namespace where a Vault-backed secret sync can be observed
- validation steps for change propagation and failure modes

## Current Step

Planned next ticket. The analysis, plan, and task breakdown are ready; implementation has not started yet.

## Key Links

- Implementation plan:
  - [01-vault-secrets-operator-plan.md](./playbooks/01-vault-secrets-operator-plan.md)

## Status

Current status: **active**

## Topics

- vault
- k3s
- kubernetes
- security
- gitops

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

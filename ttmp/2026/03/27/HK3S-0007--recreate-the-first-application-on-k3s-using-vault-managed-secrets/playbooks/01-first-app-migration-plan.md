---
Title: First app migration plan
Ticket: HK3S-0007
Status: active
Topics:
    - vault
    - k3s
    - migration
    - gitops
    - applications
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: "Decision and implementation plan for choosing and recreating the first real application on K3s using Vault-managed secrets."
LastUpdated: 2026-03-27T13:34:00-04:00
WhatFor: "Use this to choose the right first application migration and define the execution path."
WhenToUse: "Read this after the Vault platform layers are ready and before starting the first app migration."
---

# First app migration plan

## Purpose

Choose the first real application to recreate on K3s and define the migration path that uses Vault-managed secrets rather than ad hoc deployment-time environment handling.

## Candidate framing

The first app should not simply be the most important one. It should be the one that teaches the platform the most without creating unnecessary blast radius.

Evaluation criteria:

- number of external dependencies
- number and shape of secrets
- auth complexity
- persistence/database complexity
- how easy it is to validate the migrated behavior
- how representative it is of later apps

## Current likely candidates

- CoinVault
  - pro: already has a detailed Vault runtime contract
  - con: more dependencies and auth surface
- Hair-booking
  - pro: potentially smaller and easier to validate
  - con: may exercise fewer platform concerns

## Recommended execution model

1. choose the app deliberately
2. inventory current runtime/secret contract
3. map the secret contract into `kv/apps/<app>/<env>/...`
4. define the Kubernetes service account + Vault role binding
5. deploy through Argo CD
6. validate behavior against the existing deployment

## Output of the ticket

- one real K3s-hosted application
- secret delivery through Vault-derived mechanisms
- a repeatable template for later app migrations

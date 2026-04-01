---
Title: Reconcile hair-booking Keycloak SMTP from Vault on K3s
Ticket: HK3S-0021
Status: active
Topics:
    - keycloak
    - vault
    - kubernetes
    - email
    - gitops
DocType: index
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/deployment.yaml
      Note: Existing Keycloak runtime manifest that the new reconciler will extend
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/keycloak-vault-auth.yaml
      Note: Existing Kubernetes-authenticated Vault pattern in the keycloak namespace
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/keycloak.hcl
      Note: Baseline policy shape for keycloak namespace workloads
    - Path: /home/manuel/code/wesen/hair-booking/docs/keycloak-vault-smtp-sync-playbook.md
      Note: App-side SMTP sync contract and current-state runbook
    - Path: /home/manuel/code/wesen/hair-booking/ttmp/2026/03/24/HAIR-010--separate-hair-booking-keycloak-realm-and-add-signup-social-login/scripts/configure_hosted_keycloak_smtp_and_smoke.sh
      Note: Legacy operator helper whose behavior the reconciler will replace
ExternalSources: []
Summary: Add a K3s-native job that reconciles the `kv/apps/hair-booking/prod/ses` Vault secret into the Keycloak `hair-booking` realm SMTP configuration using Kubernetes auth instead of the older off-cluster AppRole helper flow, and document the resulting steady-state SMTP secret path.
LastUpdated: 2026-04-01T09:01:12.975790331-04:00
WhatFor: Finish the migration from operator-driven SMTP sync to cluster-native reconciliation so the K3s Keycloak realm keeps the hair-booking SES settings aligned with Vault.
WhenToUse: Use when implementing or reviewing the Keycloak-side SMTP reconciliation path for hair-booking on K3s, or when validating how Vault-backed app email settings should flow into Keycloak without Terraform owning SMTP secrets.
---

# Reconcile hair-booking Keycloak SMTP from Vault on K3s

## Overview

`hair-booking` is already live on K3s, and the SES secret now exists at
`kv/apps/hair-booking/prod/ses` on `vault.yolo.scapegoat.dev`. The missing
piece is steady-state reconciliation. Right now an operator can seed the secret
and run a helper to push the SMTP block into the Keycloak realm, but the
cluster does not yet own that synchronization path.

The goal of this ticket is to add a Keycloak-side reconciler job in K3s that:

- authenticates to Vault with Kubernetes auth
- reads the existing SES secret contract without changing its path
- logs into the K3s Keycloak admin API
- compares the current realm `smtpServer` block to the desired state
- updates the realm only when drift exists

This keeps the SMTP secret out of Terraform state while also removing the need
for operator-driven drift repair.

## Key Links

- **Related Files**: See frontmatter RelatedFiles field
- **External Sources**: See frontmatter ExternalSources field

## Status

Current status: **active**

Current disposition:

- `hair-booking` K3s deployment: live
- K3s Keycloak realm `hair-booking`: live
- SES secret in K3s Vault: present
- legacy operator sync helper: retained for rollback and one-off replay
- reconciler job: implemented in repo and pushed in commit `f1612d2`
- live cluster validation: completed by manual rollout; Argo adoption depends on the `keycloak` application syncing the pushed revision

## Topics

- keycloak
- vault
- kubernetes
- email
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

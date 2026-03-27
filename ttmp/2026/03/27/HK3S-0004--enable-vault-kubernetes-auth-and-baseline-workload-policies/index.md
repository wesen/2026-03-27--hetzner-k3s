---
Title: Enable Vault Kubernetes auth and baseline workload policies
Ticket: HK3S-0004
Status: complete
Topics:
    - vault
    - k3s
    - kubernetes
    - gitops
DocType: index
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: "Implementation ticket for enabling Vault Kubernetes auth on the K3s cluster, bootstrapping baseline workload policies and roles, and proving the first service-account login path."
LastUpdated: 2026-03-27T14:02:00-04:00
WhatFor: "Use this ticket to enable Vault machine auth for Kubernetes workloads, define the first baseline app policies and roles, and validate the pattern that later GitOps apps will rely on."
WhenToUse: "Read this when implementing or reviewing how Kubernetes service accounts should authenticate to the K3s-hosted Vault instance."
---

# Enable Vault Kubernetes auth and baseline workload policies

## Overview

This ticket is the first machine-auth slice after the base Vault deployment. The goal is to let Kubernetes workloads authenticate to `vault.yolo.scapegoat.dev` using their service account identity, then constrain what they can read through named Vault policies and roles. That is the foundation for every later secret-delivery path on this cluster, whether the consumer ends up using direct Vault API calls, Vault Agent, or Vault Secrets Operator.

The scope is intentionally practical rather than abstract. The ticket should leave behind:

- a configured `auth/kubernetes` mount in the new K3s Vault
- the Kubernetes RBAC needed for Vault to call the TokenReview API
- a repeatable repo-managed bootstrap script for writing the auth backend config, policies, roles, and smoke secret
- a smoke-tested workload path that proves a Kubernetes service account can log in and read only the secrets it should
- starter roles for the next real consumers, especially CoinVault and hair-booking

## Current Step

Completed: Vault Kubernetes auth is enabled on the K3s Vault instance, the smoke namespace/service account is managed through Argo CD, and a real service-account token can log in and read only its own KV subtree.

## Key Links

- Previous Vault deployment ticket:
  - [HK3S-0003 index](../HK3S-0003--implement-vault-on-k3s-via-argo-cd/index.md)
- Implementation plan:
  - [01-vault-kubernetes-auth-implementation-plan.md](./playbook/01-vault-kubernetes-auth-implementation-plan.md)
- Implementation diary:
  - [01-vault-kubernetes-auth-diary.md](./reference/01-vault-kubernetes-auth-diary.md)

## Status

Current status: **complete**

## Result

The K3s Vault now supports Kubernetes workload auth:

- auth mount: `auth/kubernetes`
- secrets engine: `kv/`
- smoke namespace/service account: `vault-auth-smoke/vault-auth-smoke`
- smoke role: `vault-auth-smoke`
- baseline future roles: `coinvault-prod`, `hair-booking-prod`
- smoke validation: passed allow and deny checks with a real Kubernetes service account token

## Next Tickets

Recommended immediate follow-ups:

- [HK3S-0005](../HK3S-0005--enable-vault-keycloak-oidc-operator-login-on-k3s/index.md) for human operator OIDC login
- [HK3S-0006](../HK3S-0006--deploy-vault-secrets-operator-on-k3s-and-prove-secret-sync/index.md) for controller-based secret delivery
- [HK3S-0007](../HK3S-0007--recreate-the-first-application-on-k3s-using-vault-managed-secrets/index.md) for the first real workload migration

## Topics

- vault
- k3s
- kubernetes
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

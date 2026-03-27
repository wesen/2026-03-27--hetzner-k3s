---
Title: Vault Kubernetes auth implementation diary
Ticket: HK3S-0004
Status: active
Topics:
    - vault
    - k3s
    - kubernetes
    - security
    - gitops
DocType: reference
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: "Chronological diary for enabling Vault Kubernetes auth and baseline workload policies on the K3s cluster."
LastUpdated: 2026-03-27T13:34:00-04:00
WhatFor: "Use this to review the exact implementation trail, including mistakes, validation steps, and follow-up decisions."
WhenToUse: "Read this when continuing or reviewing the Kubernetes-auth implementation ticket."
---

# Vault Kubernetes auth implementation diary

## Goal

Capture the implementation work for enabling Vault Kubernetes auth on the K3s cluster, including the Kubernetes RBAC setup, Vault auth backend configuration, baseline policies and roles, and the end-to-end workload validation path.

## Step 1: Open the follow-up ticket set and ground the first ticket in real consumers

The first thing I did in this ticket was make the follow-up work concrete instead of leaving it as a bullet list in `HK3S-0003`. I created four new tickets: Kubernetes auth, OIDC operator login, Vault Secrets Operator, and first app recreation on K3s. This ticket is the first of that set because it is the identity foundation every later machine-facing step depends on. Before writing tasks, I checked the existing consumer context again, especially CoinVault’s Coolify deployment docs and the current Terraform-side Vault auth hardening work, so the plan would match the real path and naming conventions already in use.

That re-check was important because “enable Kubernetes auth” can easily turn into an abstract infrastructure ticket if it is not tied back to real app contracts. CoinVault already documents its current Vault secret paths under `kv/apps/coinvault/prod/...`, and the Terraform repo already documents the human OIDC operator path and current policy style. Those two anchors are enough to define the first K3s machine-auth slice without guessing what later app tickets will need.

### Prompt Context

**User prompt (verbatim):** "cool, yes create a new ticket for that, and also new tickets for the other tickets you recommended. For each, add a detailed analysis/implementation plan and detailed tasks. 

Then, start working on the first one, task by task, committing at appropriate intervals, and updating your diary as you go"

**Assistant interpretation:** Create the next four implementation tickets, document each one with a concrete plan and task breakdown, then begin executing the Kubernetes-auth ticket immediately with diary updates and focused commits.

**Inferred user intent:** Turn the post-Vault-deployment roadmap into an actual executable sequence and start moving the next dependency layer, not just discussing it.

### What I did
- Created tickets:
  - `HK3S-0004` Kubernetes auth and baseline roles
  - `HK3S-0005` Keycloak OIDC operator login on K3s Vault
  - `HK3S-0006` Vault Secrets Operator on K3s
  - `HK3S-0007` first app recreation using Vault-managed secrets
- Re-read the finished Vault deployment ticket `HK3S-0003`.
- Inspected the CoinVault deployment docs and existing Terraform-side Vault auth/OIDC playbooks.
- Wrote the first detailed implementation plan and task breakdown for this ticket.

### Why
- The next steps should be separate tickets because they each have their own risks, validations, and rollback boundaries.
- Kubernetes auth needs to be designed with the actual app naming and secret path conventions in mind.

### What worked
- The new ticket workspaces were created cleanly.
- Existing docs gave enough context to define a concrete path for Kubernetes auth.

### What didn't work
- I initially looked for `.envrc` files directly in the target app roots and did not find them there. That was informative, but it meant the better source of truth was the actual deployment docs and runtime secret contracts rather than a root-level env file.

### What I learned
- CoinVault is the clearest first downstream consumer because its current secret paths and hosted runtime contract are already documented in detail.
- The K3s machine-auth path should align with `kv/apps/<app>/<env>/...` from the start.

### What was tricky to build
- The subtle part here was avoiding a “ticket factory” outcome where four new tickets exist but still contain vague text. The plan needed to be specific enough that a later implementer could actually start from the docs without rereading the entire repo.

### What warrants a second pair of eyes
- Whether `coinvault-prod` and `hair-booking-prod` are the right first baseline roles to create ahead of workload migration.

### What should be done in the future
- Start the repo-managed scaffold for Kubernetes auth next.

### Code review instructions
- Review:
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0004--enable-vault-kubernetes-auth-and-baseline-workload-policies/tasks.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0004--enable-vault-kubernetes-auth-and-baseline-workload-policies/tasks.md)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0004--enable-vault-kubernetes-auth-and-baseline-workload-policies/playbook/01-vault-kubernetes-auth-implementation-plan.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0004--enable-vault-kubernetes-auth-and-baseline-workload-policies/playbook/01-vault-kubernetes-auth-implementation-plan.md)
- Confirm the role/path conventions are a sensible basis for later app tickets.

### Technical details
- Internal docs inspected:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0003--implement-vault-on-k3s-via-argo-cd/index.md`
  - `/home/manuel/code/gec/2026-03-16--gec-rag/docs/deployments/coinvault-coolify.md`
  - `/home/manuel/code/gec/2026-03-16--gec-rag/docs/deployments/coinvault-hosted-operations.md`
  - `/home/manuel/code/wesen/terraform/ttmp/2026/03/25/TF-008-VAULT-AUTH-HARDENING--implement-vault-auth-hardening-with-keycloak-and-a-go-end-to-end-example/playbooks/01-vault-oidc-operator-playbook.md`

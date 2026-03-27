---
Title: Vault Secrets Operator implementation diary
Ticket: HK3S-0006
Status: active
Topics:
    - vault
    - k3s
    - kubernetes
    - gitops
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: gitops/applications/vault-secrets-operator.yaml
      Note: Repo-managed Argo CD application for the HashiCorp VSO Helm chart
    - Path: gitops/applications/vault-secrets-operator-smoke.yaml
      Note: Repo-managed Argo CD application for the smoke VaultConnection/VaultAuth/VaultStaticSecret objects
    - Path: scripts/bootstrap-vault-kubernetes-auth.sh
      Note: Existing Vault Kubernetes-auth bootstrap helper extended for the VSO smoke role and source path
    - Path: scripts/validate-vault-secrets-operator.sh
      Note: Validation helper for destination secret sync, rotation, and failure mode checks
ExternalSources: []
Summary: Chronological diary for deploying Vault Secrets Operator on K3s and proving the first Vault-to-Kubernetes secret sync path.
LastUpdated: 2026-03-27T14:35:00-04:00
WhatFor: Use this to review the exact implementation trail for the first controller-based secret delivery slice on the K3s cluster.
WhenToUse: Read this when continuing or reviewing the VSO implementation ticket.
---

# Vault Secrets Operator implementation diary

## Goal

Capture the implementation work for installing Vault Secrets Operator, wiring it to the K3s Vault through Kubernetes auth, and proving a real secret sync into a Kubernetes `Secret`.

## Step 1: Confirm the operator packaging and choose the narrowest smoke-auth model

The first thing I did in this ticket was decide how to package VSO in a way that matches the existing repo instead of introducing a second GitOps pattern. The current repo already uses an external Helm-chart Argo application for Vault itself, and a separate local Argo application for the Kubernetes-auth smoke resources. VSO fits that exact same split well: install the controller from the official HashiCorp Helm chart in its own application, then keep the first `VaultConnection`, `VaultAuth`, and `VaultStaticSecret` objects in a separate repo-local smoke application.

I also chose the smallest useful auth model for the first proof: a dedicated smoke namespace and service account, a dedicated Vault policy/role under the existing `auth/kubernetes` mount, and a single `VaultStaticSecret` that creates one destination Kubernetes `Secret`. That proves the full path without pulling a real application into the ticket prematurely.

### Prompt Context

**User prompt (verbatim):** "yes, do next ticket, task by task, committing at appropriate intervals, keeping a detailed diary."

**Assistant interpretation:** Start implementing `HK3S-0006` for real, keep checkpoints focused, and document the work as it happens.

**Inferred user intent:** Move from auth foundations to controller-based secret delivery, not just planning.

### What I did
- Read `HK3S-0006` index, tasks, and plan.
- Checked the live cluster for existing VSO CRDs and namespaces.
- Re-read the earlier design doc sections that recommended separate Argo applications for Vault and VSO.
- Pulled the official HashiCorp VSO docs and CR examples to confirm the current API surface.
- Chose:
  - operator namespace: `vault-secrets-operator-system`
  - smoke namespace: `vault-secrets-operator-smoke`
  - smoke service account / Vault role / policy: `vso-smoke`

### Why
- A split controller-app plus smoke-app model keeps lifecycle and troubleshooting clearer.
- The first proof should be small enough that failures are attributable to the controller or auth path, not app-specific complexity.

### What worked
- The existing repo structure already suggested the right packaging pattern.
- Official docs confirmed `VaultConnection`, `VaultAuth`, and `VaultStaticSecret` as the right CRD set for the first slice.

### What didn't work
- Nothing failed conceptually here. The only friction was that the local environment does not have `helm`, so I used the official chart index and docs directly instead of local Helm inspection.

### What I learned
- The current official VSO chart version in HashiCorp's Helm repo is `1.3.0`.
- The current CRD version is `secrets.hashicorp.com/v1beta1`.

### What was tricky to build
- The main design edge was choosing the ownership boundary. The controller install belongs in an external-chart Argo app. The auth and smoke objects belong in repo-local manifests so they remain easy to review and adapt later for real apps.

### What warrants a second pair of eyes
- Whether the first `VaultConnection` should use the in-cluster Vault service or the public Vault hostname. I chose the in-cluster service to keep the first proof independent of ingress/TLS.

### What should be done in the future
- Add the full scaffold next, then apply it live and validate propagation.

### Code review instructions
- Review:
  - [01-vault-secrets-operator-plan.md](../playbooks/01-vault-secrets-operator-plan.md)
  - `ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/design-doc/01-vault-on-k3s-and-gitops-migration-design.md`
- Confirm the controller-app plus smoke-app split is the right first shape.

### Technical details
- Official references used:
  - `https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso/helm`
  - `https://raw.githubusercontent.com/hashicorp/vault-secrets-operator/main/config/samples/secrets_v1beta1_vaultauth.yaml`
  - `https://raw.githubusercontent.com/hashicorp/vault-secrets-operator/main/config/samples/secrets_v1beta1_vaultstaticsecret.yaml`

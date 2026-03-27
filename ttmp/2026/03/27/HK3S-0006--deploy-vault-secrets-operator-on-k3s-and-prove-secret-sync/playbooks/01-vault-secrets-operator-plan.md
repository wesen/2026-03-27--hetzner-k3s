---
Title: Vault Secrets Operator plan
Ticket: HK3S-0006
Status: active
Topics:
    - vault
    - k3s
    - kubernetes
    - gitops
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources:
    - https://developer.hashicorp.com/vault/docs/platform/k8s/vso/sources/vault
    - https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso/sources/vault/auth
Summary: "Implementation plan for deploying Vault Secrets Operator on the K3s cluster and proving the first Vault-to-Kubernetes secret sync."
LastUpdated: 2026-03-27T14:42:00-04:00
WhatFor: "Use this to implement the controller-based secret sync path after Kubernetes auth exists."
WhenToUse: "Read this when preparing the operator/controller secret-consumption layer."
---

# Vault Secrets Operator plan

## Purpose

Install Vault Secrets Operator (VSO) on K3s and prove the first end-to-end secret sync from Vault into a Kubernetes `Secret`.

## Why this matters

Kubernetes auth solves identity. VSO solves one common delivery pattern:

- app stays Kubernetes-native
- Argo manages its manifests
- app consumes a normal Kubernetes `Secret`
- Vault remains the upstream source of truth

That is likely the most ergonomic first migration path for apps currently driven by environment variables.

## Planned outputs

- Argo CD application for VSO
- `VaultConnection`
- `VaultAuth` using Kubernetes auth
- smoke `VaultStaticSecret`
- observed propagation from Vault change to Kubernetes secret update

## Planned validation

- VSO pods healthy
- auth object healthy
- destination secret created
- update source secret in Vault -> destination secret updates

## Key design choice

Keep the first implementation narrow:

- prefer `VaultStaticSecret`
- use a non-production smoke namespace
- do not bundle app migration into the same ticket

## Chosen implementation shape

- Argo application `vault-secrets-operator` installs the official HashiCorp Helm chart from `https://helm.releases.hashicorp.com`
- Argo application `vault-secrets-operator-smoke` manages the local smoke namespace and CRs from `gitops/kustomize/vault-secrets-operator-smoke`
- the first smoke auth path uses:
  - namespace: `vault-secrets-operator-smoke`
  - service account: `vso-smoke`
  - Vault role/policy: `vso-smoke`
  - source path: `kv/apps/vso-smoke/dev/demo`

## Commands used for the scaffold step

```bash
bash -n scripts/bootstrap-vault-kubernetes-auth.sh
bash -n scripts/validate-vault-secrets-operator.sh
kubectl kustomize gitops/kustomize/vault-secrets-operator-smoke
```

## Observed implementation notes

- The local environment does not have `helm`, so chart/version confirmation came from the official HashiCorp Helm repository index and docs rather than local Helm inspection.
- The first `VaultConnection` intentionally points at the in-cluster Vault service `http://vault.vault.svc.cluster.local:8200` so the initial proof does not depend on ingress or public TLS.

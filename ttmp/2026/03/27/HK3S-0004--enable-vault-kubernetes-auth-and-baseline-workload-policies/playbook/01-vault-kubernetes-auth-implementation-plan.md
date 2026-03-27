---
Title: Vault Kubernetes auth implementation plan
Ticket: HK3S-0004
Status: active
Topics:
    - vault
    - k3s
    - kubernetes
    - security
    - gitops
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources:
    - https://developer.hashicorp.com/vault/docs/auth/kubernetes
    - https://developer.hashicorp.com/vault/api-docs/auth/kubernetes
    - https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso/sources/vault/auth
Summary: "Detailed implementation plan for enabling Vault Kubernetes auth on the K3s cluster and bootstrapping the first baseline workload policies and roles."
LastUpdated: 2026-03-27T13:34:00-04:00
WhatFor: "Use this to implement the first workload authentication path into the K3s-hosted Vault instance."
WhenToUse: "Read this before changing Vault auth backends, writing policies, or validating workload login from Kubernetes."
---

# Vault Kubernetes auth implementation plan

## Purpose

Enable the new K3s-hosted Vault instance to authenticate Kubernetes workloads by service account identity, then attach that identity to baseline Vault policies and roles that match the expected future application layout.

## Why this ticket exists

The base Vault deployment from `HK3S-0003` solved storage, TLS, availability, and auto-unseal. It did not solve the application problem. A pod still needs a way to prove who it is to Vault and receive a short-lived Vault token without baking long-lived credentials into images, manifests, or `.env` files.

Vault Kubernetes auth is the first clean answer to that problem on this cluster.

It lets a workload present:

- a Kubernetes service account JWT
- issued by this K3s cluster

to Vault, which then:

- validates the JWT through the Kubernetes TokenReview API
- maps the workload to a named Vault role
- returns a short-lived Vault token carrying only the policies that role allows

That becomes the identity backbone for later tickets, especially:

- Vault Secrets Operator
- direct app-side Vault login flows
- per-app secret isolation on K3s

## Design choice for this cluster

For this cluster, the intended design is:

- Vault runs inside Kubernetes
- the Vault server pod uses its own service account token and CA bundle when calling the Kubernetes TokenReview API
- only the Vault server service account gets `system:auth-delegator`
- workload service accounts do **not** need reviewer permissions

Why this design is the best fit here:

- it matches HashiCorp’s documented in-cluster pattern for short-lived service account tokens
- it avoids storing a separate long-lived reviewer token in Vault config
- it keeps reviewer privilege centralized on the Vault server instead of spreading it to every workload
- it minimizes the number of Kubernetes objects we need to bootstrap

## Planned output

By the end of this ticket, the system should look like this:

```text
Kubernetes workload pod
  -> mounted service account token
  -> POST auth/kubernetes/login role=<named-role> jwt=<pod-jwt>
Vault auth/kubernetes
  -> uses Vault pod's own service account token to call TokenReview
  -> verifies the workload identity
  -> maps it to a named Vault role
  -> returns a short-lived Vault token
Workload
  -> reads only its allowed kv/apps/<app>/<env>/... subtree
```

## Path and naming conventions

The baseline convention for this cluster should be:

- auth mount: `auth/kubernetes`
- KV mount: `kv/`
- secret subtree per application: `kv/apps/<app>/<env>/...`
- Kubernetes namespace per app: `<app>`
- primary service account per app: `<app>`
- Vault Kubernetes role name: `<app>-<env>`

Planned first roles:

- `vault-auth-smoke`
  - namespace: `vault-auth-smoke`
  - service account: `vault-auth-smoke`
  - secret subtree: `kv/apps/vault-auth-smoke/dev/*`
- `coinvault-prod`
  - namespace: `coinvault`
  - service account: `coinvault`
  - secret subtree: `kv/apps/coinvault/prod/*`
- `hair-booking-prod`
  - namespace: `hair-booking`
  - service account: `hair-booking`
  - secret subtree: `kv/apps/hair-booking/prod/*`

These application roles can exist before the workloads themselves exist. That is useful because it lets the policy shape stabilize early.

## Planned repo structure

The implementation should add three kinds of artifacts:

1. Vault-side policy definitions
2. Operator bootstrap/validation scripts
3. Kubernetes-side RBAC and smoke-test manifests

Proposed shape:

```text
vault/
  policies/
    kubernetes/
      smoke.hcl
      app-coinvault-prod.hcl
      app-hair-booking-prod.hcl

scripts/
  bootstrap-vault-kubernetes-auth.sh
  validate-vault-kubernetes-auth.sh

gitops/
  kustomize/
    vault-kubernetes-auth/
      clusterrolebinding-vault-auth-delegator.yaml
      namespace-vault-auth-smoke.yaml
      serviceaccount-vault-auth-smoke.yaml
      kustomization.yaml
  applications/
    vault-kubernetes-auth.yaml
```

This split matters:

- policy files belong in Git and should be reviewable
- bootstrap scripts codify the operator steps that write Vault state
- Kubernetes RBAC/manifests should be GitOps-managed through Argo CD

## Execution sequence

## Task 1: Inspect live state and confirm assumptions

Check:

- existing auth mounts
- existing secrets engines
- current service account and RBAC state in namespace `vault`
- whether `kv/` already exists or needs to be created

Success criteria:

- the implementation can branch on observed reality instead of assumptions

## Task 2: Add repo-managed policy, script, and manifest scaffold

Add:

- the policy files
- the bootstrap script
- the validation script
- the GitOps package and `Application` for Kubernetes-side RBAC/smoke objects

Success criteria:

- repo contains the full desired shape before live mutation begins

## Task 3: Apply Kubernetes-side RBAC and smoke resources

Apply:

- the `system:auth-delegator` ClusterRoleBinding for the Vault service account
- the smoke namespace/service account

Success criteria:

- Vault has the Kubernetes-side permissions it needs for TokenReview

## Task 4: Configure Vault auth and write policies/roles

Use the bootstrap script to:

- ensure `kv/` exists as KV v2 at the expected path
- enable `auth/kubernetes` if absent
- configure `auth/kubernetes/config`
- write baseline policies
- write baseline roles
- seed the smoke secret

Success criteria:

- Vault contains the full baseline workload-auth contract

## Task 5: Validate allow/deny behavior

Validation should prove:

- a real Kubernetes service account JWT can authenticate
- the resulting Vault token can read its allowed path
- the same token is denied outside that subtree

Prefer this exact proof shape:

1. Mint or retrieve a JWT for the smoke service account
2. Login through `auth/kubernetes/login`
3. Read `kv/apps/vault-auth-smoke/dev/demo`
4. Fail to read `kv/apps/coinvault/prod/runtime`

Success criteria:

- workload identity and least-privilege both work

## Failure modes to expect

- `permission denied` from Kubernetes auth login
  - likely cause: missing or wrong role bindings in Vault
- reviewer/token review failure
  - likely cause: missing `system:auth-delegator` for Vault service account
- TLS or Kubernetes host errors in auth config
  - likely cause: wrong `kubernetes_host` target or wrong CA assumptions
- `no handler for route`
  - likely cause: missing `kv/` mount or wrong KV v2 path shape
- read succeeds outside the intended subtree
  - likely cause: policy too broad

## Exit criteria

- `auth/kubernetes` is enabled and configured on the K3s Vault instance
- baseline policies and roles exist in Vault
- the Kubernetes RBAC and smoke resources are managed from repo state
- a workload JWT can authenticate and read only its own subtree
- the operator flow is fully documented in the diary

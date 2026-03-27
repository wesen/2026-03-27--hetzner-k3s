---
Title: Vault Secrets Operator architecture and implementation guide
Ticket: HK3S-0006
Status: active
Topics:
    - vault
    - k3s
    - kubernetes
    - gitops
DocType: design-doc
Intent: long-term
Owners: []
RelatedFiles:
    - Path: gitops/applications/vault-secrets-operator-smoke.yaml
      Note: Argo CD application for the smoke VSO CRs
    - Path: gitops/applications/vault-secrets-operator.yaml
      Note: Argo CD application for the HashiCorp VSO Helm chart
    - Path: gitops/kustomize/vault-secrets-operator-smoke/vault-auth.yaml
      Note: Kubernetes-auth binding used by VSO
    - Path: gitops/kustomize/vault-secrets-operator-smoke/vault-connection.yaml
      Note: In-cluster Vault connection used by the first smoke sync
    - Path: gitops/kustomize/vault-secrets-operator-smoke/vault-static-secret.yaml
      Note: First Vault-to-Kubernetes secret sync resource
    - Path: scripts/bootstrap-vault-kubernetes-auth.sh
      Note: Bootstrap helper that writes the VSO smoke role and seed data into Vault
    - Path: scripts/validate-vault-secrets-operator.sh
      Note: End-to-end validation helper for sync
ExternalSources:
    - https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso/helm
    - https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso/sources/vault/auth
    - https://developer.hashicorp.com/vault/docs/platform/k8s/vso/sources/vault
Summary: Detailed intern-facing guide explaining how Vault Secrets Operator works in this K3s repo, how it integrates with Vault Kubernetes auth and Argo CD, and how to operate and validate the first secret-sync path.
LastUpdated: 2026-03-27T15:18:00-04:00
WhatFor: Teach a new intern how Vault Secrets Operator works in this repository, why we introduced it, how it depends on Vault Kubernetes auth and Argo CD, and how to extend the pattern to real applications.
WhenToUse: Read this before modifying VSO, debugging secret sync issues, or onboarding a real application onto Vault-managed secrets in this K3s cluster.
---

# Vault Secrets Operator architecture and implementation guide

## Executive Summary

Vault Secrets Operator, usually shortened to VSO, is the controller layer that turns Vault secrets into normal Kubernetes `Secret` objects. In this repository, VSO is the bridge between the platform work we already completed and the application migrations we want to do next. We already have:

- a K3s cluster on Hetzner
- Argo CD managing cluster state from Git
- a Vault instance running inside K3s
- Vault Kubernetes auth enabled so workloads can prove identity with service account tokens
- human operator login to Vault through external Keycloak OIDC

VSO sits on top of that foundation. It watches custom Kubernetes resources such as `VaultConnection`, `VaultAuth`, and `VaultStaticSecret`, authenticates to Vault on behalf of workloads, reads data from Vault, and writes Kubernetes `Secret` objects that applications can consume.

The first implementation in this ticket is intentionally narrow. It does not migrate a real application yet. Instead, it proves the full secret-delivery path using a smoke namespace called `vault-secrets-operator-smoke`. That smoke path is small enough to debug clearly and realistic enough to serve as the blueprint for the first real app migration.

## Problem Statement

We want to move applications from semi-manual deployments and Coolify-style operations into a K3s + GitOps model. That means application configuration should be reproducible from Git, but secret values must not live in Git. This creates a practical problem:

- Argo CD is good at declarative Kubernetes state
- Vault is good at securely storing and distributing secrets
- applications usually want plain Kubernetes `Secret` objects or environment variables

Without an integration layer, teams end up doing one of the following:

- copying secrets by hand into Kubernetes
- storing long-lived static credentials in CI or shell scripts
- keeping `.envrc` files as the real source of truth
- using ad hoc one-off sync scripts with poor auditability

Those patterns do not scale well, and they make migration harder because every application ends up with a different secret story.

This ticket solves the first platform slice of that problem by adding one standard mechanism for secret delivery:

```text
Vault -> Vault Secrets Operator -> Kubernetes Secret -> Application
```

That flow preserves GitOps for configuration while keeping secret values in Vault.

## Proposed Solution

The proposed solution has two repo-managed parts:

1. Install Vault Secrets Operator itself through Argo CD from the official HashiCorp Helm chart.
2. Install a small local smoke package through Argo CD that defines:
   - one namespace
   - one service account
   - one `VaultConnection`
   - one `VaultAuth`
   - one `VaultStaticSecret`

The smoke package proves four things:

- VSO can reach Vault from inside the cluster
- VSO can authenticate through Vault Kubernetes auth
- VSO can read from the intended Vault path
- VSO writes and updates a destination Kubernetes `Secret`

At a high level, the runtime looks like this:

```text
                    +------------------------------+
                    | Git repository               |
                    |                              |
                    | - Argo Application: VSO      |
                    | - Argo Application: smoke    |
                    | - Vault policy / role files  |
                    +--------------+---------------+
                                   |
                                   v
                    +------------------------------+
                    | Argo CD                      |
                    |                              |
                    | Reconciles desired state     |
                    +--------------+---------------+
                                   |
             +---------------------+----------------------+
             |                                            |
             v                                            v
+------------------------------+          +-----------------------------------+
| VSO controller               |          | Smoke namespace resources         |
| namespace:                   |          |                                   |
| vault-secrets-operator-system|          | ServiceAccount: vso-smoke         |
|                              |          | VaultConnection: vault-connection |
| Watches VSO CRDs             |          | VaultAuth: vso-smoke              |
+---------------+--------------+          | VaultStaticSecret: vso-smoke      |
                |                         +----------------+------------------+
                |                                              |
                | authenticates with SA JWT                    | creates
                v                                              v
      +-----------------------------+             +----------------------------+
      | Vault auth/kubernetes       |             | Kubernetes Secret          |
      | role: vso-smoke             |             | name: vso-smoke-secret     |
      | policy: vso-smoke           |             +----------------------------+
      +-------------+---------------+
                    |
                    | reads
                    v
      +-----------------------------+
      | Vault KV v2                 |
      | kv/apps/vso-smoke/dev/demo  |
      +-----------------------------+
```

## Design Decisions

### Decision 1: Use VSO instead of Vault Agent injection for the first app path

We deliberately chose VSO as the first delivery mechanism instead of sidecar injection. The main reason is that most of the applications we are likely to migrate already expect Kubernetes-native secrets, environment variables, or secret-backed config files. VSO keeps the consumer side simple.

Why this is a good first step:

- Argo CD can manage the VSO objects declaratively
- application manifests stay conventional
- the destination resource is the native Kubernetes `Secret`
- it is easy to explain to a new operator
- it supports a gradual migration path

What we are trading away:

- the secret material does exist in Kubernetes `Secret` objects after sync
- some dynamic-secret use cases are less natural than with direct Vault sidecars

For this cluster and migration phase, that is acceptable.

### Decision 2: Install the controller from the official HashiCorp Helm chart

The VSO controller itself is installed by Argo CD using the official chart in [`vault-secrets-operator.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-secrets-operator.yaml). This follows the same pattern already used for platform components such as Vault itself.

Why:

- we want upstream-managed controller packaging
- Argo CD already knows how to reconcile Helm sources
- we avoid copying chart internals into this repository

### Decision 3: Keep smoke resources in a repo-local Kustomize package

The smoke objects live in [`kustomization.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/kustomization.yaml) and its sibling manifests. They are applied through the local Argo app [`vault-secrets-operator-smoke.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-secrets-operator-smoke.yaml).

Why:

- these objects are cluster-specific, not upstream artifacts
- we want easy diff review for auth bindings and secret paths
- the same pattern can be copied for future applications

### Decision 4: Use the in-cluster Vault service, not the public hostname

The smoke [`vault-connection.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/vault-connection.yaml) points to:

```text
http://vault.vault.svc.cluster.local:8200
```

This is not an accident. For the first proof, we want secret sync to depend on the fewest moving parts possible. If we used `https://vault.yolo.scapegoat.dev`, then failures might be caused by ingress, DNS, or TLS instead of the actual Vault auth path.

### Decision 5: Use a dedicated smoke role and a narrowly scoped policy

The policy in [`vso-smoke.hcl`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/vso-smoke.hcl) only grants read/list under the smoke subtree. The Kubernetes auth role in [`vso-smoke.json`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/vso-smoke.json) binds that access to:

- service account: `vso-smoke`
- namespace: `vault-secrets-operator-smoke`

This matters because the core security property we want is:

```text
workload identity -> mapped role -> mapped policy -> bounded secret paths
```

Not:

```text
cluster workload -> broad Vault token -> read almost anything
```

## Component Map

This section maps the important files and runtime objects to their responsibilities.

### Git and Argo layer

- Controller app: [`vault-secrets-operator.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-secrets-operator.yaml)
  - source: official HashiCorp Helm repo
  - job: install and reconcile the VSO controller
- Smoke app: [`vault-secrets-operator-smoke.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-secrets-operator-smoke.yaml)
  - source: local Kustomize path
  - job: install the first VSO CRs and smoke namespace

### Smoke package manifests

- Package root: [`kustomization.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/kustomization.yaml)
- Namespace: [`namespace.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/namespace.yaml)
- Service account: [`serviceaccount.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/serviceaccount.yaml)
- Vault connection: [`vault-connection.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/vault-connection.yaml)
- Vault auth binding: [`vault-auth.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/vault-auth.yaml)
- Secret sync object: [`vault-static-secret.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/vault-static-secret.yaml)

### Vault-side auth and policy layer

- Existing bootstrap extended here: [`bootstrap-vault-kubernetes-auth.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-kubernetes-auth.sh)
- Smoke policy: [`vso-smoke.hcl`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/vso-smoke.hcl)
- Smoke role: [`vso-smoke.json`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/vso-smoke.json)

### Validation layer

- End-to-end validator: [`validate-vault-secrets-operator.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-vault-secrets-operator.sh)

## End-to-End Auth and Sync Flow

This is the most important conceptual section for an intern. The system works because each layer hands off identity and intent to the next layer in a controlled way.

### Step-by-step narrative

1. Argo CD reconciles the VSO controller and the smoke manifests from Git.
2. The VSO controller begins watching `VaultConnection`, `VaultAuth`, and `VaultStaticSecret` resources.
3. VSO sees the smoke `VaultStaticSecret`.
4. That object references the smoke `VaultAuth`.
5. The smoke `VaultAuth` says:
   - use method `kubernetes`
   - mount `kubernetes`
   - role `vso-smoke`
   - service account `vso-smoke`
6. VSO obtains a token for the `vso-smoke` service account and sends it to Vault at `auth/kubernetes/login`.
7. Vault checks that JWT with the Kubernetes API and confirms:
   - the token is valid
   - it belongs to `vso-smoke`
   - it belongs to namespace `vault-secrets-operator-smoke`
8. Vault maps that identity to the role `vso-smoke`.
9. The role attaches the policy `vso-smoke`.
10. That policy allows reads only from `kv/apps/vso-smoke/dev/*`.
11. VSO reads `kv/apps/vso-smoke/dev/demo`.
12. VSO writes the returned key/value pairs into Kubernetes secret `vso-smoke-secret`.
13. When the source secret changes, VSO periodically refreshes it and updates the destination secret.

### Pseudocode model

```text
watch VaultStaticSecret as sync:
  auth = get(sync.spec.vaultAuthRef)
  conn = get(auth.spec.vaultConnectionRef)

  jwt = get_service_account_token(auth.spec.kubernetes.serviceAccount)

  vault_token = vault.auth.kubernetes.login(
    mount=auth.spec.mount,
    role=auth.spec.kubernetes.role,
    jwt=jwt,
    address=conn.spec.address
  )

  secret_data = vault.kv.read(
    mount=sync.spec.mount,
    path=sync.spec.path,
    token=vault_token
  )

  kubernetes.apply_secret(
    namespace=current_namespace,
    name=sync.spec.destination.name,
    data=secret_data
  )
```

### Request/response shape to keep in mind

Kubernetes auth login is conceptually:

```http
POST /v1/auth/kubernetes/login
Content-Type: application/json

{
  "role": "vso-smoke",
  "jwt": "<service-account-token>"
}
```

Vault KV v2 read is conceptually:

```http
GET /v1/kv/data/apps/vso-smoke/dev/demo
X-Vault-Token: <short-lived-vault-token>
```

The important design idea is that the controller never gets arbitrary access. It gets access only through the Vault role and policy mapping.

## Repository Walkthrough

This walkthrough follows the exact order a new operator should use when reviewing the implementation.

### 1. Start with the controller app

Open [`vault-secrets-operator.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-secrets-operator.yaml).

Key points to notice:

- Argo CD installs the operator from the official chart
- the install target namespace is `vault-secrets-operator-system`
- the chart version is pinned
- sync is automated, so the repo remains the source of truth

### 2. Then read the smoke app

Open [`vault-secrets-operator-smoke.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-secrets-operator-smoke.yaml).

Key point:

- this app exists only to prove the first end-to-end flow and to serve as a pattern for future apps

### 3. Read the Kustomize package in manifest order

Open:

- [`namespace.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/namespace.yaml)
- [`serviceaccount.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/serviceaccount.yaml)
- [`vault-connection.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/vault-connection.yaml)
- [`vault-auth.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/vault-auth.yaml)
- [`vault-static-secret.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/vault-static-secret.yaml)

The dependency chain is:

```text
Namespace
  -> ServiceAccount
    -> VaultAuth
      -> VaultStaticSecret
  -> VaultConnection
```

`VaultStaticSecret` depends logically on both `VaultAuth` and `VaultConnection`, even though it references only `VaultAuth` directly.

### 4. Read the Vault-side policy and role

Open:

- [`vso-smoke.hcl`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/vso-smoke.hcl)
- [`vso-smoke.json`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/vso-smoke.json)

These two files encode the actual security contract. The Kubernetes objects only describe how to ask Vault for access. These files describe what access is granted.

### 5. Read the bootstrap and validation scripts

Open:

- [`bootstrap-vault-kubernetes-auth.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-kubernetes-auth.sh)
- [`validate-vault-secrets-operator.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-vault-secrets-operator.sh)

The bootstrap script is where the Vault-side role and seed data are created. The validation script is where the behavior is proven.

## Live State in This Ticket

At the end of this ticket, the live cluster state is:

- Argo application `vault-secrets-operator`: `Synced Healthy`
- Argo application `vault-secrets-operator-smoke`: `Synced Healthy`
- namespace `vault-secrets-operator-smoke` exists
- `VaultConnection/vault-connection`: ready and healthy
- `VaultAuth/vso-smoke`: ready and healthy
- `VaultStaticSecret/vso-smoke`: synced, ready, healthy
- destination `Secret/vso-smoke-secret` exists

The validation script also proved two runtime behaviors:

- rotation works: changing the value in Vault updates the Kubernetes `Secret`
- denial works: a test CR pointing at an unauthorized path fails with a policy error

The denied test matters. A smoke sync that only proves the happy path can hide an overly broad policy. The failure probe confirms the policy boundary actually exists.

## How To Review This Ticket

If you are reviewing this work for correctness, use this sequence.

### Review order

1. Read the implementation plan in [01-vault-secrets-operator-plan.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0006--deploy-vault-secrets-operator-on-k3s-and-prove-secret-sync/playbooks/01-vault-secrets-operator-plan.md)
2. Read this guide
3. Read the implementation diary in [01-vault-secrets-operator-diary.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0006--deploy-vault-secrets-operator-on-k3s-and-prove-secret-sync/reference/01-vault-secrets-operator-diary.md)
4. Inspect the manifests and Vault policy/role files
5. Re-run the validation script against the live cluster

### Review checklist

- Does the controller app install from the upstream HashiCorp chart?
- Does the smoke app keep the repo-specific auth objects local?
- Does the Vault role bind only the intended namespace and service account?
- Does the policy allow only the intended subtree?
- Does the validation script prove both success and denial?

## API Object Reference

This section summarizes the key objects in plain language.

### `VaultConnection`

Purpose:

- describes how the operator reaches a Vault server

Important fields in this ticket:

- `spec.address`
- `spec.skipTLSVerify`

File:

- [`vault-connection.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/vault-connection.yaml)

### `VaultAuth`

Purpose:

- describes how VSO should authenticate to Vault

Important fields in this ticket:

- `spec.vaultConnectionRef`
- `spec.method`
- `spec.mount`
- `spec.kubernetes.role`
- `spec.kubernetes.serviceAccount`

File:

- [`vault-auth.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/vault-auth.yaml)

### `VaultStaticSecret`

Purpose:

- tells VSO which secret path to read and where to write the Kubernetes destination secret

Important fields in this ticket:

- `spec.vaultAuthRef`
- `spec.mount`
- `spec.type`
- `spec.path`
- `spec.refreshAfter`
- `spec.destination.name`
- `spec.destination.create`
- `spec.destination.overwrite`

File:

- [`vault-static-secret.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/vault-static-secret.yaml)

### Vault Kubernetes auth role

Purpose:

- binds Kubernetes workload identity to Vault policy

Important fields in this ticket:

- `bound_service_account_names`
- `bound_service_account_namespaces`
- `policies`

File:

- [`vso-smoke.json`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/vso-smoke.json)

### Vault policy

Purpose:

- limits which paths the issued Vault token can read

File:

- [`vso-smoke.hcl`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/vso-smoke.hcl)

## Operational Procedure

The following procedure is the practical runbook a new intern should follow when adapting this pattern for a real application.

### Phase A: Confirm prerequisites

You need:

- a healthy Vault deployment
- Vault Kubernetes auth already enabled
- Argo CD healthy
- a namespace and service account for the workload
- a Vault policy and role for that workload

Relevant earlier tickets:

- Kubernetes auth foundation: [HK3S-0004](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0004--enable-vault-kubernetes-auth-and-baseline-workload-policies/index.md)
- Human operator OIDC: [HK3S-0005](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0005--enable-vault-keycloak-oidc-operator-login-on-k3s/index.md)

### Phase B: Create or update Vault-side access

Pseudocode:

```text
define policy:
  allow read/list only under app subtree

define kubernetes auth role:
  bind namespace
  bind service account
  attach policy

write seed secret data:
  kv/apps/<app>/<env>/<name>
```

### Phase C: Create VSO resources

For a real app, you would create:

- `VaultConnection` if one does not already exist for the namespace
- `VaultAuth` for the workload identity
- one or more `VaultStaticSecret` resources for concrete secret sets

### Phase D: Verify behavior

At minimum:

- confirm destination secret exists
- change a source value in Vault and verify propagation
- attempt a denied path read and verify it fails

### Phase E: Hand off to the application

Once the destination secret is proven, the application deployment can consume it using normal Kubernetes patterns such as:

- `envFrom.secretRef`
- `env.valueFrom.secretKeyRef`
- mounted secret volumes

## Failure Modes and How To Think About Them

The main debugging skill here is separating which layer is failing.

### Failure mode 1: Argo app is unhealthy

Possible causes:

- chart fetch issue
- CRD install issue
- namespace mismatch
- invalid manifest structure

Look at:

- Argo application status
- controller-manager deployment rollout
- operator pod logs

### Failure mode 2: `VaultConnection` is not healthy

Possible causes:

- wrong address
- TLS mismatch
- network path issue

This is why the smoke test uses the in-cluster Vault service. It removes ingress and public DNS from the first debug path.

### Failure mode 3: `VaultAuth` is not healthy

Possible causes:

- wrong auth mount
- wrong role name
- wrong service account name
- namespace mismatch
- Kubernetes auth not configured correctly in Vault

Look at the role definition in [`vso-smoke.json`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/vso-smoke.json) and the bootstrap script that writes it.

### Failure mode 4: `VaultStaticSecret` exists but the secret is missing

Possible causes:

- source path does not exist
- policy denies the path
- `vaultAuthRef` is wrong
- destination settings are wrong

The validation script intentionally tests both a valid path and a denied path because those two cases look very different in practice.

### Failure mode 5: Initial sync works, rotation does not

Possible causes:

- refresh interval too long
- operator not reconciling
- path updated differently than expected

In this ticket we set:

```text
refreshAfter: 15s
```

That is intentionally short for a smoke test. Production values may be longer.

## Alternatives Considered

### Alternative 1: Vault Agent injection

This is a valid pattern, but we did not choose it for the first migration slice because:

- it is more invasive for application manifests
- it introduces sidecar and template concepts immediately
- it is less intuitive for teams expecting Kubernetes `Secret` objects

We may still use it later for applications that need direct dynamic-secret workflows.

### Alternative 2: External Secrets Operator with Vault backend

That would also work conceptually, but once we already committed to first-class Vault, using HashiCorp’s native operator reduces translation layers and keeps the docs closer to the platform we are actually running.

### Alternative 3: Manual `kubectl create secret`

This is the behavior we are trying to get away from. It is not GitOps-friendly, not auditable enough, and not a good platform pattern.

## Implementation Plan

The implementation plan for this ticket was:

1. Confirm the packaging and API shape from official HashiCorp sources.
2. Add the controller Argo application.
3. Add a repo-local smoke package with `VaultConnection`, `VaultAuth`, and `VaultStaticSecret`.
4. Extend the Vault Kubernetes auth bootstrap script so the smoke policy, role, and source data exist.
5. Apply the controller app live.
6. Apply the smoke app live.
7. Validate:
   - destination secret creation
   - propagation after source update
   - denial for unauthorized path access
8. Write the operating guide and implementation diary.

That implementation is complete at the time of writing.

## Next Step After This Ticket

The next logical ticket is to use this exact pattern for the first real application migration. The most useful thing to copy forward is not the smoke namespace itself, but the structure:

```text
application namespace
  + service account
  + vault policy
  + vault role
  + vaultauth
  + one or more vaultstaticsecret objects
  + app deployment consuming the destination secret
```

That next step is already planned in [HK3S-0007](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0007--recreate-the-first-application-on-k3s-using-vault-managed-secrets/index.md).

## Open Questions

- Should we standardize one shared `VaultConnection` per namespace, or allow each app package to own its own?
- When we migrate real applications, do we want one secret bundle per app or several smaller `VaultStaticSecret` objects grouped by concern?
- At what point, if any, do we introduce dynamic secrets instead of only static KV-backed syncs?
- Should we add policy linting or role-generation helpers before more teams start copying this pattern?

## References

Internal references:

- Kubernetes auth foundation: [HK3S-0004](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0004--enable-vault-kubernetes-auth-and-baseline-workload-policies/index.md)
- Human OIDC operator login: [HK3S-0005](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0005--enable-vault-keycloak-oidc-operator-login-on-k3s/index.md)
- First real app migration target: [HK3S-0007](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0007--recreate-the-first-application-on-k3s-using-vault-managed-secrets/index.md)
- Implementation diary: [01-vault-secrets-operator-diary.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0006--deploy-vault-secrets-operator-on-k3s-and-prove-secret-sync/reference/01-vault-secrets-operator-diary.md)
- Implementation plan: [01-vault-secrets-operator-plan.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0006--deploy-vault-secrets-operator-on-k3s-and-prove-secret-sync/playbooks/01-vault-secrets-operator-plan.md)

External references:

- HashiCorp VSO Helm docs: `https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso/helm`
- HashiCorp Vault auth source docs: `https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso/sources/vault/auth`
- HashiCorp Vault source docs: `https://developer.hashicorp.com/vault/docs/platform/k8s/vso/sources/vault`

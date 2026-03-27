---
Title: Vault K3s OIDC plan
Ticket: HK3S-0005
Status: active
Topics:
    - vault
    - k3s
    - keycloak
    - oidc
    - security
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources:
    - https://developer.hashicorp.com/vault/docs/auth/jwt
Summary: "Implementation plan for recreating the Keycloak-backed human operator login path on the K3s Vault instance."
LastUpdated: 2026-03-27T13:34:00-04:00
WhatFor: "Use this to implement human operator login through Keycloak OIDC on the K3s Vault deployment."
WhenToUse: "Read this when preparing the OIDC slice after Kubernetes auth is in place."
---

# Vault K3s OIDC plan

## Purpose

Recreate the human operator login path for the K3s-hosted Vault instance using Keycloak OIDC so operators no longer need to rely on the bootstrap root token.

## Recommended approach

- Reuse the existing Keycloak operator realm and group model where sensible
- Add or adapt a dedicated client for `vault.yolo.scapegoat.dev`
- Recreate the `oidc/` auth mount on the K3s Vault instance
- Recreate the operator role and group mapping pattern:
  - admin group -> admin policy
  - readonly group -> ops-readonly policy

## Why this is a separate ticket

Human OIDC login is operationally important, but it is independent from workload auth:

- workloads should authenticate through Kubernetes auth
- humans should authenticate through OIDC

Keeping those separate makes debugging and rollback simpler.

## Planned outputs

- Keycloak OIDC client aligned to the new Vault hostname
- Vault OIDC backend config and `operators` role
- external identity groups and aliases for operator groups
- operator playbook for browser and CLI login

## Planned validation

- browser login at `https://vault.yolo.scapegoat.dev`
- CLI login:

```bash
export VAULT_ADDR=https://vault.yolo.scapegoat.dev
vault login -method=oidc role=operators
```

- group admission:
  - allowed for operator groups
  - denied for users outside them

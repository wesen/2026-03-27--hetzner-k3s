---
Title: Vault K3s OIDC operator playbook
Ticket: HK3S-0005
Status: active
Topics:
    - vault
    - k3s
    - infra
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles:
    - Path: scripts/bootstrap-vault-oidc.sh
      Note: Canonical helper used to configure the K3s Vault OIDC backend and operator mappings
    - Path: scripts/validate-vault-oidc-config.sh
      Note: Validation helper for the Vault-side OIDC state and Keycloak redirect acceptance
    - Path: vault/policies/operators/admin.hcl
      Note: Operator admin policy for the K3s Vault
    - Path: vault/policies/operators/ops-readonly.hcl
      Note: Read-only operator policy for the K3s Vault
ExternalSources:
    - https://developer.hashicorp.com/vault/docs/auth/jwt
    - https://developer.hashicorp.com/vault/api-docs/auth/jwt
Summary: Operator procedure for understanding and using the Keycloak-backed OIDC login path on the K3s Vault deployment.
LastUpdated: 2026-03-27T14:30:00-04:00
WhatFor: Give operators a repeatable path for onboarding into the Keycloak infra realm and logging into the K3s Vault without the bootstrap root token.
WhenToUse: Use when onboarding an operator, validating the Vault OIDC control plane, or debugging human login problems on the K3s Vault.
---

# Vault K3s OIDC operator playbook

## Purpose

This playbook explains the human operator auth model for the K3s-hosted Vault instance at `https://vault.yolo.scapegoat.dev`. Normal operator access should now come from Keycloak-backed OIDC login instead of routine use of the root token.

Control plane summary:

- Keycloak realm: `infra`
- Keycloak client: `vault-oidc`
- Vault auth path: `oidc/`
- Vault OIDC role: `operators`

The `groups` claim issued by Keycloak determines which Vault external identity group the user lands in, and those external groups carry the actual Vault policies.

## Policy mapping

The current mapping is:

- Keycloak group `infra-admins`
  - Vault external group alias `infra-admins`
  - Vault policy `admin`
- Keycloak group `infra-readonly`
  - Vault external group alias `infra-readonly`
  - Vault policy `ops-readonly`

The K3s Vault role requires the OIDC token to contain one of those groups. A user who can authenticate to Keycloak but is not a member of either group should be rejected by Vault.

## Redirect URIs

The configured callback URIs are:

- UI:
  - `https://vault.yolo.scapegoat.dev/ui/vault/auth/oidc/oidc/callback`
- CLI:
  - `http://localhost:8250/oidc/callback`
  - `http://127.0.0.1:8250/oidc/callback`

These are all backed by the shared Keycloak `vault-oidc` client in the `infra` realm.

## Onboard a human operator

1. Open the Keycloak admin console at `https://auth.scapegoat.dev/admin/`.
2. Switch to realm `infra`.
3. Create or import the operator user.
4. Add the user to one of:
   - `infra-admins`
   - `infra-readonly`
5. Have the operator log in to Vault through OIDC.

Do not hand operators the root token for normal work. That token is break-glass only.

## Validate from the Vault UI

1. Open `https://vault.yolo.scapegoat.dev`.
2. Choose the OIDC auth method.
3. Use role `operators` if Vault prompts for a role.
4. Complete the Keycloak login flow.
5. Confirm the resulting session sees only the capabilities expected from the assigned group.

Expected outcomes:

- `infra-admins` can manage auth methods, identity groups, mounts, policies, and KV data.
- `infra-readonly` can inspect mounts, policies, and KV data but not write them.

## Validate from the CLI

```bash
export VAULT_ADDR=https://vault.yolo.scapegoat.dev
vault login -method=oidc role=operators
vault token lookup
```

The CLI listener will use one of the localhost callback URLs listed above. If the browser login succeeds but the CLI never completes, check that the redirect URI matches exactly and that the local listener is reachable.

## Break-glass posture

The K3s Vault root token remains necessary for bootstrap, auth-backend repair, and other exceptional recovery. It is not the normal operator workflow anymore.

Use the root token only for:

- OIDC backend repair when human login is broken
- policy or identity repair
- cluster-control-plane recovery work that no normal operator token can perform

## Common failure signatures

- `missing auth method`:
  `oidc/` was not enabled or was enabled at a different path.
- `Invalid parameter: redirect_uri`:
  Keycloak does not currently allow the callback URI the Vault role is using.
- `permission denied` after successful Keycloak login:
  the user authenticated but was not in `infra-admins` or `infra-readonly`.
- Vault login form loops or lands on an empty session:
  check the Keycloak client redirect URIs, the Vault role redirect URIs, and the `default_role` value under `auth/oidc/config`.

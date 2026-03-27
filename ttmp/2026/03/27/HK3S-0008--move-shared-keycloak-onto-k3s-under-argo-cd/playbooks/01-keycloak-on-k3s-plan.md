---
Title: Keycloak on K3s deferred implementation plan
Ticket: HK3S-0008
Status: active
Topics:
    - vault
    - k3s
    - infra
    - gitops
    - migration
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ttmp/2026/03/27/HK3S-0005--enable-vault-keycloak-oidc-operator-login-on-k3s/playbooks/02-vault-k3s-oidc-operator-playbook.md
      Note: Current Vault operator login flow that will need callback continuity during any Keycloak move
    - Path: ttmp/2026/03/27/HK3S-0006--deploy-vault-secrets-operator-on-k3s-and-prove-secret-sync/index.md
      Note: Upstream platform dependency that should be stable before moving the identity plane
    - Path: ttmp/2026/03/27/HK3S-0007--recreate-the-first-application-on-k3s-using-vault-managed-secrets/index.md
      Note: First real application migration that should be stable before moving Keycloak
ExternalSources: []
Summary: "Deferred plan for eventually moving the shared Keycloak control plane onto the K3s cluster under Argo CD."
LastUpdated: 2026-03-27T14:15:00-04:00
WhatFor: "Use this to remember the intended architecture and sequencing for moving the shared Keycloak control plane onto K3s later."
WhenToUse: "Read this when the current Vault and first-app migration work is complete enough that identity-plane consolidation becomes a sensible next phase."
---

# Keycloak on K3s deferred implementation plan

## Purpose

Capture the later-phase plan for moving the shared Keycloak control plane from the current external deployment at `auth.scapegoat.dev` onto the K3s cluster, but explicitly defer that move until the current Vault and app-migration work has stabilized.

## Current recommendation

Do not implement this yet.

Keep Keycloak external for now because:

- it preserves an out-of-cluster operator login path while the K3s platform is still maturing
- it avoids making Vault, Argo CD, applications, and identity all fail together on one single-node cluster
- it is not required to complete Vault Secrets Operator or the first real application migration

## Trigger to revisit this ticket

Revisit when all of the following are true:

- Vault on K3s is stable
- Vault Kubernetes auth and human OIDC auth are stable
- Vault Secrets Operator is deployed and proven
- at least one real application has been recreated on K3s successfully
- the team wants tighter GitOps ownership of the shared identity plane

## Recommended migration shape

Recommended sequence:

1. Stand up Keycloak in K3s on a parallel hostname.
2. Prove realm/client/group behavior there first.
3. Test Vault operator login and at least one application login against the new instance.
4. Only then decide whether to cut over `auth.scapegoat.dev`.

That avoids turning “move Keycloak” into an all-at-once hostname and data migration.

## Main design questions

- Data store:
  - in-cluster Postgres
  - external Postgres
- Packaging:
  - Helm under Argo CD
  - Kustomize-wrapped Helm
  - plain manifests
- Migration style:
  - export/import realm data
  - rebuild from Terraform plus selective user migration
  - direct database migration
- Cutover:
  - parallel hostname then swap
  - direct hostname takeover

## Main risks

- identity plane and workload plane fail together on a single-node cluster
- insufficient backup and restore coverage for realm data
- callback drift across Vault and application OIDC clients during cutover
- hidden dependency on the external Keycloak admin workflow

## Existing anchors in this repo

- Current external Keycloak realm/client management:
  - [/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/hosted/main.tf](/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/hosted/main.tf)
- Current Vault OIDC dependence on external Keycloak:
  - [HK3S-0005 index](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0005--enable-vault-keycloak-oidc-operator-login-on-k3s/index.md)
  - [02-vault-k3s-oidc-operator-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0005--enable-vault-keycloak-oidc-operator-login-on-k3s/playbooks/02-vault-k3s-oidc-operator-playbook.md)
- Current cluster deployment and GitOps shape:
  - [README.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/README.md)
  - [docs/argocd-app-setup.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/argocd-app-setup.md)

## Acceptance criteria for the future implementation

- Vault operator OIDC login works against the in-cluster Keycloak
- at least one application OIDC flow works against the in-cluster Keycloak
- the new Keycloak deployment is GitOps-managed under Argo CD
- backups and restore are tested
- rollback from cutover is documented and practical

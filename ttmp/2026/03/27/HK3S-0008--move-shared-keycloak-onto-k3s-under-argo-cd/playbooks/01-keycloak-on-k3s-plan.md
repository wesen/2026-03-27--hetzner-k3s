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
    - Path: ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/index.md
      Note: Shared PostgreSQL now exists on-cluster and should be the preferred Keycloak backing store candidate
ExternalSources: []
Summary: "Implementation plan for moving the shared Keycloak control plane onto the K3s cluster under Argo CD, updated now that the parallel `infra` slice is fully validated."
LastUpdated: 2026-03-28T17:31:03-04:00
WhatFor: "Use this to remember the intended architecture and sequencing for moving the shared Keycloak control plane onto K3s later."
WhenToUse: "Read this when the current Vault and first-app migration work is complete enough that identity-plane consolidation becomes a sensible next phase."
---

# Keycloak on K3s implementation plan

## Purpose

Capture the implementation plan for moving the shared Keycloak control plane from the current external deployment at `auth.scapegoat.dev` onto the K3s cluster. The parallel `infra` slice is now live and validated; the remaining work is future realm migration and any eventual external-host cutover.

## Current recommendation

Implement this as a parallel-host rollout, not as a direct cutover.

Keep Keycloak external during the rollout because:

- it preserves an out-of-cluster operator login path while the K3s platform is still maturing
- it avoids making Vault, Argo CD, applications, and identity all fail together on one single-node cluster
- it remains the rollback path while the new in-cluster Keycloak is being validated

## Trigger to revisit this ticket

Revisit when all of the following are true:

- Vault on K3s is stable
- Vault Kubernetes auth and human OIDC auth are stable
- Vault Secrets Operator is deployed and proven
- at least one real application has been recreated on K3s successfully
- the team wants tighter GitOps ownership of the shared identity plane

Current note:

- the first four conditions are now satisfied
- the remaining trigger is organizational and operational, not technical

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
- Current shared PostgreSQL service:
  - [HK3S-0009 index](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/index.md)
  - [statefulset.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/postgres/statefulset.yaml)
  - [vault-static-secret.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/postgres/vault-static-secret.yaml)

## Updated recommendation now that PostgreSQL is live

The original version of this ticket left the backing-store choice open. That was reasonable before shared cluster data services existed. It is no longer the best framing.

If this ticket is activated, the default plan should be:

1. deploy Keycloak on K3s behind a parallel hostname
2. back it with the shared PostgreSQL service at `postgres.postgres.svc.cluster.local:5432`
3. provision a dedicated Keycloak database and service user through the same Vault/VSO pattern used for the other shared services
   - use a Vault-backed PostgreSQL bootstrap `Job`, documented in [vault-backed-postgres-bootstrap-job-pattern.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/vault-backed-postgres-bootstrap-job-pattern.md)
4. keep `auth.scapegoat.dev` external until the parallel K3s instance has proven Vault login and at least one application login

That reduces the remaining design surface. The hard questions are now cutover, backup/restore, and callback continuity, not whether the cluster has a plausible database target.

## Immediate execution order for this ticket

1. Confirm this should happen on the current single-node cluster and keep external Keycloak as rollback.
2. Choose the packaging model and parallel hostname.
3. Add Vault policies, roles, and bootstrap helpers for:
   - Keycloak runtime DB secret
   - Keycloak bootstrap-admin secret
   - Keycloak DB bootstrap Job access
4. Add the Keycloak package and Argo `Application`.
5. Add the PostgreSQL bootstrap `Job` and validate that the `keycloak` database and `keycloak_app` role are created.
6. Bring Keycloak up on the parallel hostname.
7. Validate the admin login and then the Terraform-driven realm/client recreation path.

Current progress note:

- steps 1 through 7 are now complete for the `infra` realm slice
- the base runtime, Terraform-driven `infra` realm recreation, Vault operator login, a realm-backed browser login, and database backup/restore validation are all proven
- the next live step is not more platform plumbing; it is deciding whether and when to migrate non-`infra` realms and whether to cut over `auth.scapegoat.dev`

## Validated current state

The following are now true on the live cluster:

- Argo app `keycloak` is `Synced Healthy`
- `https://auth.yolo.scapegoat.dev` serves a valid certificate
- the `infra` realm and `vault-oidc` client exist on the in-cluster Keycloak through the Terraform `k3s-parallel` environment
- Vault `oidc/` now points at `https://auth.yolo.scapegoat.dev/realms/infra`
- browser login to Vault works through the new Keycloak instance
- browser login to the Keycloak Account Console for the `infra` realm works
- a logical PostgreSQL dump/restore smoke test succeeds through [validate-keycloak-backup-restore.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-keycloak-backup-restore.sh)

Those validations prove the new identity plane can authenticate humans, back itself with shared PostgreSQL, and survive a database-level restore workflow. They do not yet mean the team should cut over the public `auth.scapegoat.dev` hostname.

## Acceptance criteria for the future implementation

- Vault operator OIDC login works against the in-cluster Keycloak
- at least one application OIDC flow works against the in-cluster Keycloak
- the new Keycloak deployment is GitOps-managed under Argo CD
- backups and restore are tested
- rollback from cutover is documented and practical

Current acceptance note:

- the criteria above are satisfied for the `infra` realm parallel slice
- the remaining open question is business/operator cutover, not technical feasibility

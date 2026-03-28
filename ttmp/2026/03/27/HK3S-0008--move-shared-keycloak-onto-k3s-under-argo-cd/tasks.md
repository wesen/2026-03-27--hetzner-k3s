# Tasks

## Phase 1: Preconditions

- [x] Wait until `HK3S-0006` and `HK3S-0007` are complete and stable enough that the cluster has a proven app and secrets delivery path
- [x] Reconfirm that keeping Keycloak external is no longer buying meaningful recovery or operational simplicity beyond serving as the rollback path
- [x] Decide that this move should be implemented on the current single-node cluster as a parallel-host rollout rather than waiting for a multi-node upgrade

## Phase 2: Architecture and data model

- [x] Choose the preferred runtime shape:
  shared in-cluster Postgres is now the default recommendation, while external Postgres remains the fallback if the team wants to preserve stronger control-plane separation
- [x] Decide whether to migrate the existing shared Keycloak instance in place, restore from export, or rebuild realm/client state from Terraform and only migrate operator/application data
- [x] Adopt the Vault-backed PostgreSQL bootstrap `Job` pattern for the `keycloak` database and `keycloak_app` role
- [ ] Define backup, restore, and disaster-recovery procedures for realms, clients, groups, users, and identity-provider settings

## Phase 3: GitOps packaging

- [x] Choose the packaging model for K3s:
  vendor chart, Kustomize-wrapped chart, or plain manifests under Argo CD
- [x] Choose the parallel hostname for the in-cluster Keycloak deployment
- [x] Add Vault policy, role, and bootstrap helpers for Keycloak runtime secrets and the database-bootstrap Job
- [x] Add the Keycloak Argo CD application and cluster resources
- [x] Add the PostgreSQL bootstrap Job and its synced secrets
- [x] Add ingress, TLS, storage, and secret wiring for the new in-cluster deployment

## Phase 4: Migration design

- [x] Design realm migration for `infra` first, then any shared application realms
- [x] Plan hostname strategy:
  parallel hostname first, then cutover, or direct takeover of `auth.scapegoat.dev`
- [x] Plan OIDC client continuity for Vault and application callbacks during the transition
- [x] Define rollback boundaries if the new Keycloak instance fails after cutover

## Phase 5: Validation and handoff

- [ ] Validate Vault operator login against the in-cluster Keycloak
- [ ] Validate at least one application login flow against the in-cluster Keycloak
- [ ] Validate backup and restore procedures before decommissioning the external deployment
- [x] Validate the ticket with `docmgr doctor`

# Tasks

## Phase 1: Preconditions

- [ ] Wait until `HK3S-0006` and `HK3S-0007` are complete and stable enough that the cluster has a proven app and secrets delivery path
- [ ] Reconfirm that keeping Keycloak external is no longer buying meaningful recovery or operational simplicity
- [ ] Decide whether this move should be done on the current single-node cluster or after a multi-node K3s upgrade

## Phase 2: Architecture and data model

- [ ] Choose the runtime shape:
  in-cluster Postgres, external Postgres, or another persistent store
- [ ] Decide whether to migrate the existing shared Keycloak instance in place, restore from export, or rebuild realm/client state from Terraform and only migrate operator/application data
- [ ] Define backup, restore, and disaster-recovery procedures for realms, clients, groups, users, and identity-provider settings

## Phase 3: GitOps packaging

- [ ] Choose the packaging model for K3s:
  vendor chart, Kustomize-wrapped chart, or plain manifests under Argo CD
- [ ] Add the Keycloak Argo CD application and cluster resources
- [ ] Add ingress, TLS, storage, and secret wiring for the new in-cluster deployment

## Phase 4: Migration design

- [ ] Design realm migration for `infra` first, then any shared application realms
- [ ] Plan hostname strategy:
  parallel hostname first, then cutover, or direct takeover of `auth.scapegoat.dev`
- [ ] Plan OIDC client continuity for Vault and application callbacks during the transition
- [ ] Define rollback boundaries if the new Keycloak instance fails after cutover

## Phase 5: Validation and handoff

- [ ] Validate Vault operator login against the in-cluster Keycloak
- [ ] Validate at least one application login flow against the in-cluster Keycloak
- [ ] Validate backup and restore procedures before decommissioning the external deployment
- [ ] Validate the ticket with `docmgr doctor`

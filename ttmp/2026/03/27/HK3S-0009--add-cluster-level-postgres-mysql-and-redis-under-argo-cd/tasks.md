# Tasks

## Phase 1: Preconditions

- [x] Wait until `HK3S-0006` and at least one application migration ticket are complete and stable
- [x] Reconfirm that applications actually need shared cluster data services rather than app-local databases or external managed services
- [x] Decide whether this work belongs on the current single-node K3s cluster or after a multi-node upgrade

## Phase 2: Service architecture

- [x] Decide the intended role of each service:
  shared platform Postgres, shared platform MySQL, shared platform Redis, or only a subset
- [x] Choose the packaging/runtime model for each:
  operator, vendor chart, Kustomize-wrapped chart, or plain manifests
- [x] Define tenancy boundaries:
  shared instance with per-app databases/users, or per-app instances managed through common platform patterns

## Phase 3: State, storage, and backup

- [x] Define persistence and storage-class expectations for each service
- [ ] Define backup and restore procedures for Postgres, MySQL, and Redis
- [ ] Define upgrade and rollback procedures for engine versions and chart/operator versions

## Phase 4: Secret and access model

- [x] Decide how service credentials should be generated and distributed through Vault
- [x] Decide whether applications consume credentials through Vault Secrets Operator, direct Vault API login, or another path
- [x] Define network policy, namespace, and service-discovery boundaries for shared data services

## Phase 5: GitOps packaging and validation

- [x] Add the Argo CD applications and manifests for the chosen shared services
- [x] Validate health, persistence, and restart behavior
- [x] Validate one application consumption path for each selected shared service
- [x] Validate the ticket with `docmgr doctor`

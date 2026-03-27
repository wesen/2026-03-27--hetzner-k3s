# Tasks

## Phase 1: Preconditions

- [ ] Wait until `HK3S-0006` and at least one application migration ticket are complete and stable
- [ ] Reconfirm that applications actually need shared cluster data services rather than app-local databases or external managed services
- [ ] Decide whether this work belongs on the current single-node K3s cluster or after a multi-node upgrade

## Phase 2: Service architecture

- [ ] Decide the intended role of each service:
  shared platform Postgres, shared platform MySQL, shared platform Redis, or only a subset
- [ ] Choose the packaging/runtime model for each:
  operator, vendor chart, Kustomize-wrapped chart, or plain manifests
- [ ] Define tenancy boundaries:
  shared instance with per-app databases/users, or per-app instances managed through common platform patterns

## Phase 3: State, storage, and backup

- [ ] Define persistence and storage-class expectations for each service
- [ ] Define backup and restore procedures for Postgres, MySQL, and Redis
- [ ] Define upgrade and rollback procedures for engine versions and chart/operator versions

## Phase 4: Secret and access model

- [ ] Decide how service credentials should be generated and distributed through Vault
- [ ] Decide whether applications consume credentials through Vault Secrets Operator, direct Vault API login, or another path
- [ ] Define network policy, namespace, and service-discovery boundaries for shared data services

## Phase 5: GitOps packaging and validation

- [ ] Add the Argo CD applications and manifests for the chosen shared services
- [ ] Validate health, persistence, and restart behavior
- [ ] Validate one application consumption path for each selected shared service
- [ ] Validate the ticket with `docmgr doctor`

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
- [x] Define backup and restore procedures for Postgres, MySQL, and Redis
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

## Phase 6: Shared PostgreSQL rollout

- [x] Add shared PostgreSQL design notes and concrete rollout tasks to this ticket
- [x] Add Vault policy, role, and bootstrap script for `kv/infra/postgres/cluster`
- [x] Add Argo CD application and Kustomize manifests for the shared PostgreSQL service
- [x] Deploy PostgreSQL on the cluster and validate readiness, SQL access, and restart behavior

## Phase 7: Shared Redis rollout

- [x] Add shared Redis design notes and concrete rollout tasks to this ticket
- [x] Add Vault policy, role, and bootstrap script for `kv/infra/redis/cluster`
- [x] Add Argo CD application and Kustomize manifests for the shared Redis service
- [x] Deploy Redis on the cluster and validate auth, persistence, and restart behavior

## Phase 8: Off-cluster backup target

- [x] Add a Terraform-managed Hetzner Object Storage bucket for cluster data-service backups
- [x] Enable bucket versioning and define the bucket-prefix layout for `postgres/`, `mysql/`, and `redis/`
- [x] Document the operator input contract for the object-storage management credentials without committing secrets

## Phase 9: Vault and secret-delivery path for backup jobs

- [x] Define a shared Vault KV path for backup object-storage credentials
- [x] Add a replayable HK3S-0009 ticket script that writes the object-storage runtime credentials into Vault
- [x] Extend the PostgreSQL, MySQL, and Redis Kubernetes-auth policies so their backup jobs can read the shared backup-storage secret path
- [x] Add VSO `VaultStaticSecret` manifests in each service namespace for the backup-storage secret

## Phase 10: Scheduled backup jobs

- [x] Add a PostgreSQL backup CronJob that produces a logical dump and uploads it to the off-cluster bucket
- [x] Add a MySQL backup CronJob that produces a logical dump and uploads it to the off-cluster bucket
- [x] Add a Redis backup CronJob that snapshots the durable on-disk state and uploads it to the off-cluster bucket
- [x] Keep the backup command logic replayable by storing the operator scripts under the HK3S-0009 ticket `scripts/` folder

## Phase 11: Validation and restore drills

- [x] Run each backup path manually once and verify that an artifact lands in object storage under the expected prefix
- [x] Restore PostgreSQL into a scratch database or scratch namespace and verify real objects come back
- [x] Restore MySQL into a scratch database or scratch namespace and verify real tables come back
- [x] Restore Redis into a scratch namespace or one-shot pod and verify the validation key survives the round trip
- [x] Update the diary, changelog, and ticket index with the backup/restore outcomes and the remaining upgrade/rollback work

## Phase 12: Restore-drill findings follow-up

- [ ] Investigate and resolve the orphaned Draft Review foreign-key references surfaced during the PostgreSQL scratch restore replay

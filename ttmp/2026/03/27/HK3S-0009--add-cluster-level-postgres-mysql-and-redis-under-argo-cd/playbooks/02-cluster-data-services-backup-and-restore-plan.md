---
Title: Cluster data services backup and restore plan
Ticket: HK3S-0009
Status: active
Topics:
    - k3s
    - infra
    - gitops
    - migration
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/wesen/terraform/storage/apps/hair-booking/photos/envs/prod/main.tf
      Note: Existing Hetzner Object Storage Terraform pattern
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/postgres/statefulset.yaml
      Note: Shared PostgreSQL runtime to back up
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/mysql/statefulset.yaml
      Note: Shared MySQL runtime to back up
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/redis/statefulset.yaml
      Note: Shared Redis runtime to back up
ExternalSources: []
Summary: "Implementation and replay plan for off-cluster backups and scratch restore drills of the shared PostgreSQL, MySQL, and Redis services using Hetzner Object Storage, Vault/VSO-delivered credentials, and repo-managed CronJobs."
---

# Cluster data services backup and restore plan

## Goal

Add real off-cluster backups for the shared PostgreSQL, MySQL, and Redis services and prove that each service can be restored from the produced artifacts.

This plan is no longer hypothetical. The backup jobs are live, and the first scratch restore drills have already been executed. The ticket-local scripts in `scripts/` are the replay surface for the exact operator path that was used.

## Recommended shape

Use one private Hetzner Object Storage bucket with versioning enabled and service-specific prefixes:

- `postgres/`
- `mysql/`
- `redis/`

Use one shared Vault secret path for the object-storage runtime credentials:

- `kv/infra/backups/object-storage`

Then, in each service namespace:

- sync the object-storage credentials into Kubernetes with VSO
- run a CronJob that creates the service-specific backup artifact
- upload that artifact to the shared bucket under the service prefix

## Ticket-local replay scripts

The following scripts under [`scripts/`](../scripts) are the replayable operator surface for this slice:

- `00-common.sh`
- `01-seed-backup-object-storage-secret.sh`
- `02-trigger-postgres-backup-job.sh`
- `03-trigger-mysql-backup-job.sh`
- `04-trigger-redis-backup-job.sh`
- `05-list-backup-objects.sh`
- `06-prune-backup-object.sh`
- `07-restore-postgres-backup-to-scratch.sh`
- `08-restore-mysql-backup-to-scratch.sh`
- `09-restore-redis-backup-to-scratch.sh`

## Why this shape

- The cluster is single-node, so “backups” that stay on the node are not enough.
- Hetzner Object Storage is already a proven Terraform pattern in the shared Terraform repo.
- Bucket-level separation is not available as true least-privilege IAM in the current Hetzner Object Storage setup, so one bucket plus prefixes is the pragmatic path.
- VSO keeps the storage credentials out of Git and out of handwritten Kubernetes `Secret` manifests.

## Service-specific backup format

### PostgreSQL

Use a logical SQL dump of the full cluster:

- command family: `pg_dumpall`
- output: compressed `.sql.gz`

Why:

- the service now backs multiple logical databases such as Keycloak and Draft Review
- a single-cluster logical dump is the most useful operational artifact at the current scale

### MySQL

Use a logical dump:

- command family: `mysqldump --all-databases --single-transaction --routines --events`
- output: compressed `.sql.gz`

Why:

- CoinVault depends on application-level table content, not only server configuration
- logical restore drills are easier to validate than physical volume copies

### Redis

Use the durable on-disk state already produced by the running server:

- copy `/data/dump.rdb`
- if present, also copy `/data/appendonlydir/*`
- package into a compressed tarball

Why:

- the runtime already has AOF enabled
- logical export is not the primary Redis recovery mechanism here
- copying the durable files is closer to the real persistence contract

## Restore validation model

Do not restore directly into the live primary first.

Instead:

1. download the chosen artifact
2. restore into a scratch database or scratch namespace
3. run verification queries
4. only then use the same procedure for a real recovery

## Observed scratch restore results

### PostgreSQL

The PostgreSQL scratch restore replayed the latest cluster dump and recreated the logical databases:

- `draft_review`
- `keycloak`
- `platform`
- `postgres`

The validation query against `draft_review.users` returned `2`, which proves the dump is materially useful.

However, the replay also surfaced real foreign-key violations in Draft Review data. `psql` reported missing parent rows under `review_sessions` for several descendant tables, including:

- `reactions`
- `review_paragraph_progress`
- `review_section_progress`
- `review_summaries`

The missing `review_session_id` observed during the drill was:

- `212fdf9c-373d-4a05-bc9e-3082e09f1674`

Treat this as a real data-integrity follow-up, not as a restore-script bug.

### MySQL

The MySQL scratch restore succeeded cleanly once the restore pod used the official `mysql:8.4` image, a local Unix socket for root auth, and an increased redo log capacity. The restored validation query returned:

- `gec_products=8926`

### Redis

The Redis scratch restore succeeded cleanly in a one-shot pod. The restored validation values were:

- `dbsize=1`
- `cluster_persistence=redis-1774726040`

That proves the durable key used by the Redis validation contract survived the backup and restore round trip.

## Immediate execution order

1. Create the backup bucket in Terraform.
2. Seed the object-storage runtime credentials into Vault.
3. Extend the PostgreSQL, MySQL, and Redis Vault policies to allow reading that shared backup secret.
4. Add VSO backup-storage secrets per namespace.
5. Add the three CronJobs.
6. Run each backup manually once.
7. Perform one restore drill per service.

## Remaining follow-up

- Define and validate explicit upgrade procedures for PostgreSQL, MySQL, and Redis engine versions.
- Define rollback procedures for failed version upgrades.
- Investigate and fix the orphaned Draft Review foreign-key references surfaced during the PostgreSQL restore replay.

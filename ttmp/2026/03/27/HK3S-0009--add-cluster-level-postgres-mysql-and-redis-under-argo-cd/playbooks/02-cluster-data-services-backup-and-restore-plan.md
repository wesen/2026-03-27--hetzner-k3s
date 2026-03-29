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
Summary: "Implementation plan for off-cluster backups of the shared PostgreSQL, MySQL, and Redis services using Hetzner Object Storage, Vault/VSO-delivered credentials, and repo-managed CronJobs."
---

# Cluster data services backup and restore plan

## Goal

Add real off-cluster backups for the shared PostgreSQL, MySQL, and Redis services and prove that each service can be restored from the produced artifacts.

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

## Immediate execution order

1. Create the backup bucket in Terraform.
2. Seed the object-storage runtime credentials into Vault.
3. Extend the PostgreSQL, MySQL, and Redis Vault policies to allow reading that shared backup secret.
4. Add VSO backup-storage secrets per namespace.
5. Add the three CronJobs.
6. Run each backup manually once.
7. Perform one restore drill per service.


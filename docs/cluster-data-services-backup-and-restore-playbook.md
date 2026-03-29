---
Title: "Back Up and Restore Shared PostgreSQL, MySQL, and Redis on This K3s Platform"
Slug: "cluster-data-services-backup-and-restore-playbook"
Short: "Operate the shared PostgreSQL, MySQL, and Redis backup pipeline on this K3s cluster, including object storage, Vault/VSO secret delivery, manual backup triggers, scratch restore drills, and failure handling."
Topics:
- backup
- restore
- postgres
- mysql
- redis
- vault
- argocd
- kubernetes
- object-storage
- disaster-recovery
Commands:
- terraform
- vault
- kubectl
- aws
- bash
Flags: []
IsTopLevel: true
IsTemplate: false
ShowPerDefault: true
SectionType: Tutorial
---

## What This Page Covers

This page is the operator playbook for the shared data-service backup pipeline on this K3s platform.

It explains:

- how backups are wired for shared PostgreSQL, MySQL, and Redis
- where the off-cluster artifacts go
- how the runtime credentials are delivered
- how to trigger backups manually
- how to restore each service safely into a scratch target
- what validation to run before calling a backup usable
- what known sharp edges already showed up during the first restore drills

This page is meant to be the practical companion to the HK3S-0009 ticket history. A new intern should be able to read this page and understand the normal operator path without reading the whole ticket diary first.

## The System You Are Operating

The backup system is split across four layers:

```text
Terraform
  -> creates the Hetzner Object Storage bucket

Vault
  -> stores object-storage runtime credentials

Vault Secrets Operator
  -> syncs those credentials into service namespaces

Argo CD + Kustomize
  -> runs the backup CronJobs for postgres, mysql, and redis
```

The live storage target is one private Hetzner Object Storage bucket with service-specific prefixes:

- `postgres/`
- `mysql/`
- `redis/`

The live runtime secret path in Vault is:

- `kv/infra/backups/object-storage`

## Why the System Is Split This Way

The split is deliberate.

Terraform should own the object-storage bucket because that bucket is infrastructure, not workload state.

Vault should own the runtime credential material because those keys should not live in Git.

VSO should carry those credentials into Kubernetes because this repo already uses Vault-backed secret delivery elsewhere, and the backup pipeline should not introduce a second secret-management model.

Argo CD should own the CronJobs because backup execution is now part of the declared platform state, not an ad hoc operator habit.

If you collapse those responsibilities into one layer, the system becomes harder to reason about and harder to secure.

## The Important Files

### Terraform layer

- [main.tf](/home/manuel/code/wesen/terraform/storage/platform/k3s-backups/envs/prod/main.tf)
- [variables.tf](/home/manuel/code/wesen/terraform/storage/platform/k3s-backups/envs/prod/variables.tf)
- [outputs.tf](/home/manuel/code/wesen/terraform/storage/platform/k3s-backups/envs/prod/outputs.tf)

### GitOps backup jobs

- [backup-cronjob.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/postgres/backup-cronjob.yaml)
- [backup-cronjob.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/mysql/backup-cronjob.yaml)
- [backup-cronjob.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/redis/backup-cronjob.yaml)

### VSO delivery

- [backup-storage-vault-static-secret.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/postgres/backup-storage-vault-static-secret.yaml)
- [backup-storage-vault-static-secret.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/mysql/backup-storage-vault-static-secret.yaml)
- [backup-storage-vault-static-secret.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/redis/backup-storage-vault-static-secret.yaml)

### Ticket-local replay scripts

- [00-common.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/00-common.sh)
- [01-seed-backup-object-storage-secret.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/01-seed-backup-object-storage-secret.sh)
- [02-trigger-postgres-backup-job.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/02-trigger-postgres-backup-job.sh)
- [03-trigger-mysql-backup-job.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/03-trigger-mysql-backup-job.sh)
- [04-trigger-redis-backup-job.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/04-trigger-redis-backup-job.sh)
- [05-list-backup-objects.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/05-list-backup-objects.sh)
- [06-prune-backup-object.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/06-prune-backup-object.sh)
- [07-restore-postgres-backup-to-scratch.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/07-restore-postgres-backup-to-scratch.sh)
- [08-restore-mysql-backup-to-scratch.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/08-restore-mysql-backup-to-scratch.sh)
- [09-restore-redis-backup-to-scratch.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/09-restore-redis-backup-to-scratch.sh)

## Before You Touch Anything

Make sure you have:

- a working kubeconfig for this cluster
- Vault access on `https://vault.yolo.scapegoat.dev`
- the local Vault token file or exported `VAULT_TOKEN`
- `aws`, `vault`, `kubectl`, and `bash`
- access to the Terraform repo if you need to inspect the object-storage bucket definition

The safest starting environment is:

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
./scripts/get-kubeconfig-tailscale.sh
export KUBECONFIG=$PWD/kubeconfig-<tailscale-host>.yaml
export VAULT_ADDR=https://vault.yolo.scapegoat.dev
```

The replay scripts will fall back to `~/.vault-token` if `VAULT_TOKEN` is not already exported.

## How the Backup Pipeline Works

The service-specific CronJobs all follow the same high-level contract:

1. read object-storage credentials from the VSO-synced `backup-storage` Secret
2. create a service-appropriate artifact
3. upload that artifact to the right prefix in the backup bucket

The concrete artifact formats are:

- PostgreSQL: compressed full-cluster SQL dump
- MySQL: compressed all-databases logical dump
- Redis: compressed archive of durable on-disk state

That is important because the restore path depends on the artifact type. Do not treat all three engines as if they have the same recovery model.

## How to Seed or Reseed the Object-Storage Secret

Use the ticket-local script:

```bash
./ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/01-seed-backup-object-storage-secret.sh
```

What it does:

- reads the object-storage access key, secret key, endpoint, bucket, and region from local operator inputs
- writes them into Vault at `kv/infra/backups/object-storage`

Why it exists:

- the bucket is Terraform-managed
- the runtime credentials belong in Vault
- we want a replayable operator path, not a one-off shell snippet

## How to Trigger Manual Backups

Use the trigger scripts instead of hand-assembling `kubectl create job --from=cronjob/...` commands every time:

```bash
./ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/02-trigger-postgres-backup-job.sh
./ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/03-trigger-mysql-backup-job.sh
./ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/04-trigger-redis-backup-job.sh
```

Then list the remote objects:

```bash
./ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/05-list-backup-objects.sh
```

Expected shape:

```text
postgres/postgres-<timestamp>.sql.gz
mysql/mysql-<timestamp>.sql.gz
redis/redis-<timestamp>.tar.gz
```

If a clearly bad artifact lands, remove it explicitly with:

```bash
./ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/06-prune-backup-object.sh mysql/mysql-<bad-object>.sql.gz
```

## Backup Validation Checklist

Do not call a backup successful just because a CronJob completed.

Validate all of these:

- the CronJob-created Job finished successfully
- the remote object exists in the expected prefix
- the artifact is plausibly non-empty
- the restore drill for that engine still works against the current format

This matters because one of the first MySQL backup runs uploaded a 20-byte object after the dump itself had already failed. A present object is not automatically a good object.

## Safe Restore Model

Never restore directly into the live primary first.

The safe sequence is:

1. choose the latest or target artifact
2. restore into an isolated scratch pod or scratch database
3. run validation queries
4. only then consider a real recovery operation

That is the whole point of the restore scripts. They are not production restore commands. They are safe validation drills.

## PostgreSQL Restore Drill

Use:

```bash
./ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/07-restore-postgres-backup-to-scratch.sh
```

What the script does:

- downloads the latest `postgres/` object from the backup bucket
- launches a scratch `postgres:16-alpine` pod in the `postgres` namespace
- initializes a local data directory as the `postgres` user
- starts a scratch local PostgreSQL server
- replays the cluster dump
- validates the recreated database list and `draft_review.users`

The current successful validation looked like:

```text
databases:
draft_review
keycloak
platform
postgres
draft_review_users=2
```

### Important current caveat

The PostgreSQL restore drill also surfaced real Draft Review foreign-key violations. `psql` reported missing parent rows under `review_sessions` for tables such as:

- `reactions`
- `review_paragraph_progress`
- `review_section_progress`
- `review_summaries`

Treat that as a live data-quality issue, not as a backup-script failure.

### What “success” means here

Success means:

- the dump is materially restorable
- the expected logical databases come back
- known application objects come back

It does **not** yet mean “the Draft Review dataset is perfectly clean.” That is still a follow-up item.

## MySQL Restore Drill

Use:

```bash
./ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/08-restore-mysql-backup-to-scratch.sh
```

What the script does:

- downloads the latest `mysql/` object
- launches a scratch `mysql:8.4` pod in the `mysql` namespace
- initializes a new insecure datadir
- starts `mysqld` locally
- restores the dump through the Unix socket
- validates the database list and `gec.products`

The current successful validation looked like:

```text
databases:
gec
information_schema
mysql
performance_schema
sys
gec_products=8926
```

### Important implementation notes

The restore script uses:

- local socket auth, not TCP
- a larger redo log capacity

Those are not cosmetic details. They were required to make the scratch restore succeed on the real dataset.

## Redis Restore Drill

Use:

```bash
./ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/09-restore-redis-backup-to-scratch.sh
```

What the script does:

- downloads the latest `redis/` object
- launches a scratch `redis:7-alpine` pod in the `redis` namespace
- unpacks the archive
- finds the backed-up `.rdb`
- starts a scratch Redis server on port `6380`
- validates the dataset size and the persistence marker key

The current successful validation looked like:

```text
dbsize=1
cluster_persistence=redis-1774726040
```

### Important implementation notes

The script is intentionally BusyBox-safe. It does **not** assume Bash inside the container, and it emits the Redis log on startup failure.

That detail matters because the first version silently relied on shell features BusyBox `sh` does not support.

## Failure Modes You Should Expect

### Backup object exists but is bogus

Symptoms:

- tiny file in object storage
- job logs show dump failure

Meaning:

- the upload path worked
- the backup command did not

Action:

- inspect job logs
- prune the bad object
- rerun after fixing the dump command

### Vault/VSO secret delivery broken

Symptoms:

- backup job cannot authenticate to object storage
- missing `backup-storage` Secret in namespace

Action:

- check `VaultStaticSecret` health
- verify `kv/infra/backups/object-storage`
- verify the service Vault policy includes read access to that path

### MySQL client mismatch

Symptoms:

- TLS errors
- `caching_sha2_password` plugin errors

Action:

- use the official MySQL client family
- avoid Alpine MariaDB client assumptions for MySQL 8

### Scratch restore script hangs

Symptoms:

- pod stays up but validation never prints

Action:

- inspect scratch pod logs
- inspect startup command assumptions
- check whether the script assumed Bash features inside BusyBox images

### PostgreSQL restore reports data errors

Symptoms:

- `psql` reports foreign-key violations during replay

Meaning:

- the dump is exposing live data inconsistency

Action:

- record the finding
- validate what did restore
- open a separate data-quality follow-up if needed

## Operator Runbook

### Normal weekly or ad hoc verification

1. Check Argo app health:

   ```bash
   kubectl -n argocd get applications postgres mysql redis
   ```

2. Check backup CronJobs:

   ```bash
   kubectl -n postgres get cronjob postgres-backup
   kubectl -n mysql get cronjob mysql-backup
   kubectl -n redis get cronjob redis-backup
   ```

3. Trigger manual backups if needed:

   ```bash
   ./ttmp/.../scripts/02-trigger-postgres-backup-job.sh
   ./ttmp/.../scripts/03-trigger-mysql-backup-job.sh
   ./ttmp/.../scripts/04-trigger-redis-backup-job.sh
   ```

4. List remote objects:

   ```bash
   ./ttmp/.../scripts/05-list-backup-objects.sh
   ```

5. Run one or more scratch restore drills:

   ```bash
   ./ttmp/.../scripts/07-restore-postgres-backup-to-scratch.sh
   ./ttmp/.../scripts/08-restore-mysql-backup-to-scratch.sh
   ./ttmp/.../scripts/09-restore-redis-backup-to-scratch.sh
   ```

### After a real pipeline change

If you change:

- bucket settings
- Vault secret shape
- service backup images
- dump flags
- restore script logic

then rerun:

- at least one manual backup
- at least one scratch restore for the affected engine

Do not rely on YAML review alone.

## Pseudocode for the Operating Model

```text
for each service in [postgres, mysql, redis]:
  read backup-storage credentials from namespaced Secret
  create engine-appropriate artifact
  verify artifact is non-empty / valid
  upload artifact to s3://scapegoat-k3s-backups/<service>/

for each service restore drill:
  choose latest artifact
  download artifact locally
  start isolated scratch pod
  restore artifact into scratch engine
  run known-good validation query or key lookup
  if validation fails:
    inspect logs
    decide whether this is script failure, engine mismatch, or live data issue
```

## What Is Still Not Done

This playbook covers backup and restore operations. It does not yet cover:

- version-upgrade playbooks for PostgreSQL, MySQL, and Redis
- rollback playbooks for failed engine upgrades
- automated periodic restore verification
- cleanup of the Draft Review PostgreSQL orphaned references

Those are the next logical hardening tasks.

## Related History

- Ticket index:
  - [HK3S-0009 index](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/index.md)
- Ticket implementation diary:
  - [01-cluster-data-services-implementation-diary.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/reference/01-cluster-data-services-implementation-diary.md)
- Backup pipeline postmortem:
  - [02-cluster-data-services-backup-pipeline-postmortem.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/reference/02-cluster-data-services-backup-pipeline-postmortem.md)

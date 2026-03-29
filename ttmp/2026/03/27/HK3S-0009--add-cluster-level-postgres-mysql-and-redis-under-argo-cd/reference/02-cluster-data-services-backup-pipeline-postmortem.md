---
Title: Cluster data services backup pipeline postmortem
Ticket: HK3S-0009
Status: active
Topics:
    - k3s
    - infra
    - gitops
    - backup
    - restore
    - postgres
    - mysql
    - redis
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/wesen/terraform/storage/platform/k3s-backups/envs/prod/main.tf
      Note: Terraform-managed Hetzner Object Storage bucket used by the backup pipeline
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/postgres/backup-cronjob.yaml
      Note: Live PostgreSQL backup CronJob
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/mysql/backup-cronjob.yaml
      Note: Live MySQL backup CronJob
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/redis/backup-cronjob.yaml
      Note: Live Redis backup CronJob
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/00-common.sh
      Note: Shared helper used by all replayable backup and restore scripts
ExternalSources: []
Summary: "Detailed postmortem for building the shared PostgreSQL, MySQL, and Redis backup and scratch-restore pipeline, with emphasis on the real failures, why they happened, and how the final operator surface was shaped."
LastUpdated: 2026-03-29T17:45:00-04:00
WhatFor: "Use this to understand the engineering lessons behind the shared data-service backup pipeline rather than just the final happy-path commands."
WhenToUse: "Read this when extending, debugging, or redesigning the backup and restore path for the shared cluster data services."
---

# Cluster data services backup pipeline postmortem

## Executive summary

This postmortem covers the work that turned HK3S-0009 from “three shared data services exist” into “three shared data services can be backed up off-cluster and replayed into safe scratch targets.”

The end state is:

- shared PostgreSQL, MySQL, and Redis each have a GitOps-managed backup CronJob
- all three jobs upload off-cluster artifacts into a Terraform-managed Hetzner Object Storage bucket
- object-storage credentials are distributed through Vault and Vault Secrets Operator, not committed Kubernetes `Secret` manifests
- all three artifact types have been restored into scratch targets using replayable ticket-local scripts

The most important outcome is not just that the scripts worked. The more important outcome is that the restore drills exposed the exact places where our assumptions were wrong:

- MySQL backup and restore needed the official MySQL client family, not the Alpine MariaDB client
- Redis restore scripts needed to be BusyBox-safe and log on startup failure
- PostgreSQL restore revealed an actual Draft Review data-integrity issue instead of silently pretending the dump was perfect

That means the backup pipeline did what it should do: it gave us a recovery mechanism and it also surfaced hidden operational and data-quality risks before an emergency.

## What problem we were solving

By the time HK3S-0009 reached the backup slice, the cluster already had three shared stateful services:

- PostgreSQL for Keycloak and Draft Review
- MySQL for CoinVault
- Redis for shared in-cluster key/value state

That was already useful, but it had one major weakness: all durable state still lived on a single node. In a single-node cluster, “the PVC exists” is not a recovery story. If the node disappears, the local-path volumes disappear with it.

So the real problem was:

- create off-cluster backups for all three services
- keep the credentials and delivery path aligned with the rest of the platform
- prove that the produced artifacts are not just files but actually restorable

## The architecture we chose

The final architecture is:

```text
Terraform
  -> Hetzner Object Storage bucket + versioning

Vault
  -> kv/infra/backups/object-storage

Vault Secrets Operator
  -> backup-storage Secret in postgres/mysql/redis namespaces

Argo CD + Kustomize
  -> backup CronJobs per service

CronJobs
  -> produce service-specific artifact
  -> upload to service-specific prefix in object storage

Operator replay scripts
  -> trigger manual runs
  -> inspect object storage
  -> restore into scratch targets
```

The bucket-prefix contract is:

- `postgres/`
- `mysql/`
- `redis/`

The shared Vault path is:

- `kv/infra/backups/object-storage`

This shape is important because it keeps ownership aligned:

- Terraform owns the off-cluster storage resource
- Vault owns the runtime credentials
- GitOps owns the jobs and Kubernetes wiring
- ticket-local scripts own the replayable operator path

## Why this architecture was the right fit

This repository already had a working Terraform pattern for Hetzner Object Storage elsewhere, so creating a new bucket with the MinIO-compatible provider was a low-risk extension rather than a new subsystem. The more important design choice was not the bucket itself, but where to put the credentials.

Using handwritten Kubernetes `Secret` manifests would have been technically easy and operationally wrong. The cluster already uses Vault and VSO for runtime secret delivery. Introducing a parallel “for backups we just commit a secret” pattern would have been a regression.

Likewise, putting the backup logic only into ad hoc workstation commands would have made the ticket non-replayable. The user explicitly asked for the scripts to live under the ticket `scripts/` folder, and that was the right constraint. It forced the operator workflow to become explicit and reviewable instead of hiding in terminal history.

## Timeline and decision flow

### 1. Establish the off-cluster target

The first move was to create the storage target in Terraform at [main.tf](/home/manuel/code/wesen/terraform/storage/platform/k3s-backups/envs/prod/main.tf).

That gave us:

- bucket `scapegoat-k3s-backups`
- versioning enabled
- stable service prefixes

This part was straightforward because it reused an existing repo pattern.

### 2. Put the runtime storage credentials in Vault

The next move was intentionally not Kubernetes. The object-storage runtime contract needed to land in Vault first so that the services could consume it through the same machine-auth path they already use for app secrets.

That became:

- Vault path `kv/infra/backups/object-storage`
- replay script [01-seed-backup-object-storage-secret.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/01-seed-backup-object-storage-secret.sh)

This was the right place to keep the mutable access key and secret key because the storage account is operational state, not application source code.

### 3. Extend the Vault/VSO policy surface

Once the storage secret existed in Vault, each data-service namespace needed permission to read it. That meant extending the service-specific Vault policies for:

- PostgreSQL
- MySQL
- Redis

and then adding per-namespace VSO `VaultStaticSecret` resources named `backup-storage`.

That decision mattered because it preserved least privilege at the namespace/service-account level while still allowing one shared object-storage credential set.

### 4. Add GitOps-managed backup CronJobs

Each service got a repo-owned CronJob:

- [backup-cronjob.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/postgres/backup-cronjob.yaml)
- [backup-cronjob.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/mysql/backup-cronjob.yaml)
- [backup-cronjob.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/redis/backup-cronjob.yaml)

These jobs deliberately use service-appropriate artifact formats:

- PostgreSQL: compressed `pg_dumpall`
- MySQL: compressed `mysqldump --all-databases`
- Redis: tarball of on-disk durable state

This was not just a formatting choice. It reflects the real recovery contract for each engine.

### 5. Run manual backup jobs before pretending the schedule is enough

The platform should never assume a CronJob works just because the YAML applied. The next step was to trigger each backup path manually and check that real artifacts landed in the bucket.

PostgreSQL and Redis worked immediately.

MySQL did not.

That failure is one of the most useful parts of the whole exercise.

## Failure analysis

### Failure 1: MySQL backup used the wrong client family

The first MySQL backup path used an Alpine-based MariaDB client container. That looked reasonable until the live server and the client disagreed about auth and TLS behavior.

The first observed error was:

```text
TLS/SSL error: self-signed certificate in certificate chain
```

The backup script still produced a tiny object, which was an immediate design smell. A backup job that can upload a bogus file while the real dump failed is operationally dangerous.

That led to the first hardening pass:

- dump to a real file first
- verify it is non-empty
- only upload after that check

That prevented silent bad artifacts, but the next error then became visible:

```text
Plugin caching_sha2_password could not be loaded
```

That was the real incompatibility. The MariaDB client family was simply the wrong tool for a MySQL 8 server using modern auth defaults.

#### Root cause

The root cause was not “a typo in a flag.” It was assuming that “MariaDB client on Alpine” is operationally interchangeable with “MySQL 8 client.” For the server we are actually running, it is not.

#### Fix

The final fix was to switch the backup job to the official `mysql:8.4` image and install `awscli` there. That aligns the dump toolchain with the server family and restored support for `--ssl-mode=DISABLED`.

#### Lesson

For stateful service automation, use the official client family unless you have a strong reason not to. “Close enough” tools create avoidable restore risk.

### Failure 2: MySQL restore assumed the wrong local auth path

The first MySQL scratch restore tried to connect over TCP as root to the locally initialized scratch server. That failed with:

```text
Host '127.0.0.1' is not allowed to connect to this MySQL server
```

That was not a networking issue. It was a mismatch between how a fresh insecure local instance expects to be administered and how the script was trying to reach it.

#### Root cause

The restore script was treating the scratch server like a remote service instead of like a locally bootstrapped engine.

#### Fix

Use the Unix socket, not TCP, for the local scratch restore path.

#### Lesson

Scratch restore jobs should prefer the most local, deterministic auth path available. On a one-shot local MySQL server, that is the socket.

### Failure 3: MySQL restore needed more redo log capacity

Once the auth method was fixed, the replay still struggled with:

```text
Threads are unable to reserve space in redo log
```

#### Root cause

The scratch server was running with redo-log defaults that were too small for the imported dataset.

#### Fix

Start the scratch server with:

- `--innodb-redo-log-capacity=1073741824`

#### Lesson

A restore drill is not just “can the SQL parse?” It is also “can the engine actually ingest the dataset under realistic server settings?”

### Failure 4: Redis restore script assumed shell features BusyBox `sh` does not have

The first Redis restore run looked like a hang. The actual problem was that the script used:

- `set -euo pipefail`

inside BusyBox `sh`, where `pipefail` is not valid. It also did not emit the Redis startup log if the server failed to boot.

#### Root cause

The script was written as if it would always execute under Bash semantics, but the container entrypoint used BusyBox `sh`.

#### Fix

- use `set -eu`
- search recursively for the `.rdb` file
- print `/tmp/redis.log` before failing if the scratch server never becomes ready

#### Lesson

Ticket replay scripts should target the actual shell available in the container, not the shell on the operator workstation.

### Failure 5: PostgreSQL restore exposed real application-data inconsistency

The PostgreSQL restore was the most important failure because it was not a scripting failure at all. Once the scratch server booted correctly and the cluster dump replayed, `psql` reported foreign-key violations in Draft Review data for rows referencing a missing `review_sessions` parent.

That is not a problem in `pg_dumpall`. That is a problem in the application data we currently have.

#### Root cause

The live dataset contains orphaned relationships under `review_sessions`.

#### Fix

There is no script-only fix here. The correct follow-up is a separate data-integrity investigation for Draft Review.

#### Lesson

Restore drills are not just pipeline validation. They are also a diagnostic for latent application-data issues.

## What worked unusually well

Several design choices paid off:

- Ticket-local scripts kept the operator path explicit and replayable.
- Vault plus VSO was the right secret-delivery model for backup credentials.
- Service-specific formats were the right choice; none of the restore drills would have been easier with a fake “one format for all” abstraction.
- The Hetzner Object Storage bucket plus prefixes was a pragmatic choice for a single-node platform.
- Scratch restore targets were low-risk operationally and high-value diagnostically.

## What was still awkward

The ticket scripts initially depended on `VAULT_TOKEN` being exported, while normal CLI usage often relies on `~/.vault-token`. That made non-interactive replay weaker than the operator reality.

Fixing [00-common.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/00-common.sh) to fall back to the local token file made the script layer more faithful to how an operator actually works on this machine.

That is a small detail, but it matters. Replay scripts should minimize hidden workstation assumptions.

## Final validated outcomes

### PostgreSQL

Validated:

- scratch server boot
- full cluster dump replay
- recreated logical databases
- `draft_review.users=2`

Finding:

- orphaned Draft Review rows referencing missing `review_sessions`

### MySQL

Validated:

- scratch server boot
- full dump replay
- clean validation query
- `gec_products=8926`

### Redis

Validated:

- scratch server boot
- durable state replay from RDB archive
- `dbsize=1`
- `cluster_persistence=redis-1774726040`

## What we should do differently next time

- Prefer official engine clients earlier for both backup and restore jobs.
- Add “artifact must be non-empty before upload” checks from the start.
- Treat scratch restore drills as part of the initial rollout definition, not as a later hardening step.
- Keep ticket-local scripts in place whenever the operator workflow is non-trivial.
- Expect restore drills to reveal application-data issues and design the ticket scope to capture those findings cleanly.

## Recommended follow-up work

1. Write and validate explicit upgrade and rollback playbooks for PostgreSQL, MySQL, and Redis.
2. Investigate the Draft Review PostgreSQL orphaned relationships surfaced by the restore replay.
3. Decide whether backup retention should stay purely bucket-versioning-based or gain explicit pruning automation.
4. Consider whether PostgreSQL and MySQL restore drills should eventually run in a more automated periodic validation loop.

## Files to review with this postmortem

- Ticket backup/restore plan:
  - [02-cluster-data-services-backup-and-restore-plan.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/playbooks/02-cluster-data-services-backup-and-restore-plan.md)
- Ticket implementation diary:
  - [01-cluster-data-services-implementation-diary.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/reference/01-cluster-data-services-implementation-diary.md)
- Replay scripts:
  - [00-common.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/00-common.sh)
  - [07-restore-postgres-backup-to-scratch.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/07-restore-postgres-backup-to-scratch.sh)
  - [08-restore-mysql-backup-to-scratch.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/08-restore-mysql-backup-to-scratch.sh)
  - [09-restore-redis-backup-to-scratch.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/09-restore-redis-backup-to-scratch.sh)

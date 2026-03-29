---
Title: Vault snapshot and Hetzner server backup strategy
Ticket: HK3S-0017
Status: active
Topics:
    - vault
    - backup
    - restore
    - hetzner
    - terraform
    - disaster-recovery
DocType: design
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault.yaml
      Note: Live Vault deployment using integrated Raft and AWS KMS auto-unseal
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/main.tf
      Note: Hetzner server resource that should expose automatic Backups
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/playbooks/02-cluster-data-services-backup-and-restore-plan.md
      Note: Existing object-storage backup pattern for the shared data services
ExternalSources: []
Summary: "Design guide for adding Vault Raft snapshots and Hetzner server backups as complementary recovery layers in this single-node K3s environment."
---

# Vault snapshot and Hetzner server backup strategy

## The two problems we are solving

This ticket intentionally covers two backup layers that are related but not interchangeable.

### Problem 1: Vault control-plane recovery

Vault holds the secrets and auth control plane for the rest of the cluster. If Vault data is lost, rebuilding the cluster from Git is not enough because Git does not contain the live secret material.

That means Vault needs a service-specific backup mechanism.

In this environment, the correct backup primitive is:

- Vault integrated Raft snapshot

not:

- copying the local PVC
- relying on the full VM backup as the only control-plane recovery story

### Problem 2: Whole-node recovery

This cluster is still a single Hetzner VM. There is operational value in being able to say:

- “recover the entire node as it looked recently”

That is a different recovery objective from “recover Vault cleanly.”

For that objective, the correct primitive is:

- Hetzner automatic Backups on the server resource

not:

- a custom in-cluster workaround
- pretending a Git rebuild is equivalent to whole-node recovery

## Why both layers are needed

These layers protect different failure modes.

### Vault snapshot protects:

- live secret material
- auth backends and policies
- identity state
- token/accessor state that is persisted in Raft

### Hetzner server backup protects:

- `/var/lib/rancher/k3s`
- local-path volumes
- node-local binaries and cluster cert state
- “the node looked like this yesterday” recovery

### Neither one replaces the other

If you only keep the VM backup:

- you have a coarse machine recovery path
- but no disciplined, service-specific Vault artifact

If you only keep Vault snapshots:

- you protect the secret control plane
- but not the rest of the node-local cluster state

So the correct design is:

```text
Git
  -> declarative source of truth

Hetzner automatic Backups
  -> coarse full-node recovery

Vault Raft snapshots
  -> structured Vault data recovery

Service-level backups
  -> PostgreSQL, MySQL, Redis recovery
```

## Why not “just snapshot the VM”

A full-VM backup feels simple, but it has three problems as the only recovery story:

1. It is coarse-grained.
   You recover the whole machine, not just the Vault dataset.

2. It is less reviewable.
   A VM backup does not tell you whether the service-level restore path is actually correct.

3. It does not exercise the service contract.
   A Vault snapshot drill validates Vault. A VM restore does not necessarily validate the service’s own recovery tooling.

So VM backups are valuable, but they are not a replacement for Vault-native snapshots.

## Why not “just rely on Git”

Git is already the right source of truth for:

- Terraform
- Argo CD applications
- Kustomize packages
- workload shapes

Git is not the source of truth for:

- live Vault secrets
- live Raft state
- Kubernetes runtime state on the node

So Git reduces the blast radius of infrastructure loss, but it does not remove the need for runtime backups.

## Vault backup strategy

### Storage model

Vault currently runs with:

- integrated Raft
- a local-path-backed PVC
- AWS KMS auto-unseal

That means the correct artifact is a Raft snapshot, not a filesystem tarball.

### Execution model

The snapshot path should be:

1. a namespaced CronJob in `vault`
2. authenticating to Vault through the existing Kubernetes auth backend
3. using a dedicated service account and least-privilege policy
4. writing the snapshot artifact to a temp file
5. uploading it to the existing Hetzner Object Storage backup bucket under:
   - `vault/`

### Why Kubernetes auth matters

We should not mount the Vault root token into Kubernetes just to take snapshots.

The cluster already has Vault Kubernetes auth. So the cleaner path is:

- service account JWT
- login to `auth/kubernetes/login`
- receive a token with a policy that can create/read the snapshot endpoint

That keeps the automation aligned with the rest of the platform’s machine-auth model.

### Why reuse the existing backup bucket

HK3S-0009 already proved:

- Hetzner Object Storage works
- Vault/VSO delivery of storage creds works
- off-cluster object storage is the right operator path here

So we should not create a second bucket or second credential model unless a real isolation requirement appears.

The pragmatic shape is:

- same bucket
- new prefix `vault/`

## Hetzner server backup strategy

### What to use

Use Hetzner automatic server Backups on the `hcloud_server` resource.

This is different from manual snapshots:

- snapshots are ad hoc and operator-triggered
- Backups are the provider’s recurring server-level mechanism

For this ticket, the right implementation is:

- set `backups = true` on the server resource

and then document the resulting recovery model clearly.

### What not to over-engineer

Do not build a fake scheduler around manual snapshots if Hetzner already offers automatic server backups. That adds operator burden without giving a better default recovery posture.

### What it means operationally

Hetzner Backups should be treated as:

- coarse node recovery
- helpful when the whole machine or local K3s state is the problem

not as:

- replacement for Vault snapshots
- replacement for PostgreSQL/MySQL/Redis service backups

## Restore strategy

### Vault

The eventual restore path should be documented around:

- starting an isolated or replacement Vault with compatible seal config
- restoring from a Raft snapshot artifact
- validating expected secrets or auth objects

Whether we do a full live scratch restore in this ticket depends on how safely we can isolate it. If that cannot be done without mutating the live cluster, the correct move is to implement the snapshot pipeline now and document the restore procedure explicitly rather than pretending we proved a safe drill.

### Hetzner server

Server-backup restore is not something we “GitOps” into the cluster. It is a provider-side recovery action and should be documented as:

- when to use it
- what you expect to get back
- when you should prefer rebuilding from Terraform and Git instead

## Recommended implementation order

1. Create the ticket docs and tasks.
2. Enable Hetzner automatic Backups in Terraform.
3. Add the Vault snapshot policy and Kubernetes auth role.
4. Add the Vault namespace object-storage secret delivery.
5. Add the Vault snapshot CronJob.
6. Run one manual snapshot backup and verify the `vault/` artifact.
7. Write the restore/operator docs based on the real implementation.

## Success criteria

This ticket is successful when:

- Terraform shows the K3s server with automatic Backups enabled
- the live cluster can produce a Vault Raft snapshot artifact into object storage
- the operator path is captured as replayable ticket-local scripts
- the docs clearly distinguish:
  - Git recovery
  - VM recovery
  - Vault recovery
  - service-level DB recovery

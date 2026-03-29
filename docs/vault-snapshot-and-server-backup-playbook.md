---
Title: "Operate Vault Snapshots and Hetzner Server Backups"
Slug: "vault-snapshot-and-server-backup-playbook"
Short: "Run, verify, and restore Vault Raft snapshots, and understand how Hetzner automatic server Backups fit into the cluster recovery model."
Topics:
- vault
- backup
- restore
- hetzner
- terraform
- disaster-recovery
Commands:
- vault
- kubectl
- aws
- terraform
- ssh
Flags: []
IsTopLevel: true
IsTemplate: false
ShowPerDefault: true
SectionType: Tutorial
---

## What This Page Covers

This page explains the two recovery layers that protect the control plane of this cluster:

- Vault Raft snapshots uploaded off-cluster
- Hetzner automatic server Backups for coarse whole-node recovery

These layers solve different problems. You need both.

Vault snapshots protect:

- secret data
- auth backends
- policies
- roles
- the usable state of the secrets control plane

Hetzner server Backups protect:

- the VM itself
- `/var/lib/rancher/k3s`
- local-path volumes
- the general node filesystem state

If you only have node Backups, Vault recovery is coarse and awkward. If you only have Vault snapshots, you still do not have a fast whole-node recovery path.

## Architecture

The live recovery model looks like this:

```text
Terraform
  -> enables Hetzner automatic Backups on the server resource

Vault Kubernetes auth
  -> authenticates a dedicated vault-backup service account

Vault backup CronJob
  -> creates a Raft snapshot
  -> compresses it
  -> uploads it to Hetzner Object Storage

Hetzner Object Storage
  -> stores vault/*.snap.gz artifacts off-cluster
```

## What Lives Where

- [`main.tf`](../main.tf)
  - Hetzner server resource with `backups = var.server_backups_enabled`
- [`variables.tf`](../variables.tf)
  - operator-facing variable for enabling provider Backups
- [`gitops/applications/vault-backup.yaml`](../gitops/applications/vault-backup.yaml)
  - Argo CD application for the Vault snapshot runtime surface
- [`gitops/kustomize/vault-backup/`](../gitops/kustomize/vault-backup)
  - service account, `VaultAuth`, `VaultConnection`, `VaultStaticSecret`, and `CronJob`
- [HK3S-0017 index](../ttmp/2026/03/29/HK3S-0017--implement-vault-snapshots-and-hetzner-server-backups/index.md)
  - full implementation ticket
- [HK3S-0017 scripts](../ttmp/2026/03/29/HK3S-0017--implement-vault-snapshots-and-hetzner-server-backups/scripts)
  - replayable operator helpers

## Current Live State

This playbook matches the current cluster state:

- Hetzner automatic Backups are enabled on the K3s node
- Vault snapshot CronJob exists in namespace `vault`
- off-cluster uploads land in:
  - `s3://scapegoat-k3s-backups/vault/`

First validated artifact:

- `vault/vault-20260329T201050Z.snap.gz`
- size: `134956` bytes

## Prerequisites

You need:

- `kubectl`
- `vault`
- `aws`
- access to the K3s cluster
- a valid Vault token locally
- access to the object-storage credentials stored in Vault

The preferred operator path is now Tailscale. If needed, review:

- [docs/tailscale-k3s-admin-access-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/tailscale-k3s-admin-access-playbook.md)

## Step 1: Confirm Hetzner Server Backups Are Enabled

The provider-level node recovery layer is controlled by Terraform, not by Kubernetes.

Check the live Terraform state:

```bash
terraform state show hcloud_server.node | sed -n '1,200p'
```

You should see:

```text
backups = true
```

Important detail:

- `backup_window` is provider-owned and computed
- this repo enables Backups, but does not pick the exact window

So the correct operator mental model is:

- Git controls whether Backups are enabled
- Hetzner controls when its backup window occurs

## Step 2: Bootstrap Vault-Side Auth for the Snapshot Job

The snapshot job does not use a root token. It logs into Vault through the Kubernetes auth backend.

Replayable script:

```bash
VAULT_ADDR=https://vault.yolo.scapegoat.dev \
  bash ttmp/2026/03/29/HK3S-0017--implement-vault-snapshots-and-hetzner-server-backups/scripts/01-bootstrap-vault-backup-auth.sh
```

What this ensures:

- policy `vault-backup` exists
- Kubernetes auth role `vault-backup` exists
- the service account identity in namespace `vault` can authenticate for snapshot creation

## Step 3: Ensure the GitOps Runtime Surface Exists

The runtime surface is the `vault-backup` Argo application plus its Kustomize package.

Apply or refresh it:

```bash
kubectl apply -f gitops/applications/vault-backup.yaml
kubectl -n argocd annotate application vault-backup argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd get application vault-backup -o wide
```

Then verify the runtime objects:

```bash
kubectl -n vault get serviceaccount vault-backup
kubectl -n vault get vaultauth vault-backup
kubectl -n vault get vaultconnection vault-connection
kubectl -n vault get vaultstaticsecret backup-storage
kubectl -n vault get secret backup-storage
kubectl -n vault get cronjob vault-backup
```

You want all of these to exist before triggering a manual snapshot.

## Step 4: Run a Manual Vault Snapshot

Replayable script:

```bash
KUBECONFIG_PATH=<path-to-kubeconfig> \
  bash ttmp/2026/03/29/HK3S-0017--implement-vault-snapshots-and-hetzner-server-backups/scripts/02-trigger-vault-backup-job.sh
```

Expected output shape:

```text
uploaded=vault/vault-<timestamp>.snap.gz
[hk3s-0017] triggered vault-backup-manual-<timestamp>
```

This proves all of the following in one run:

- the service account token is usable
- Vault Kubernetes auth login works
- the `vault-backup` policy has the correct permissions
- the Raft snapshot endpoint works
- the object-storage credentials from Vault were delivered successfully
- the upload path to Hetzner Object Storage is valid

## Step 5: Verify the Uploaded Object

Replayable script:

```bash
VAULT_ADDR=https://vault.yolo.scapegoat.dev \
  bash ttmp/2026/03/29/HK3S-0017--implement-vault-snapshots-and-hetzner-server-backups/scripts/03-list-vault-backup-objects.sh
```

Expected output shape:

```text
2026-03-29 16:10:51     134956 vault/vault-20260329T201050Z.snap.gz
```

What to check:

- object key starts with `vault/`
- timestamp is UTC-shaped
- size is non-zero
- newer runs append new objects instead of overwriting old ones

## Step 6: Understand the Restore Model

Vault restore is more dangerous than the shared data-service scratch restores.

Why:

- Vault is itself a control plane
- restoring a snapshot into the live instance can replace current secrets and auth state
- this cluster is single-node and uses local-path storage

Because of that, the current decision is:

- scratch restore stays documented-only for now
- live operator procedure is documented carefully
- do not perform an ad hoc restore into the live cluster without an explicit incident decision

## Vault Restore Procedure

The safe operator sequence in an incident is:

1. identify the snapshot object to restore
2. download it from object storage
3. stop or isolate the target Vault instance
4. ensure you understand whether you are restoring:
   - onto the current node
   - onto a rebuilt node
   - into a replacement cluster
5. run `vault operator raft snapshot restore`
6. validate Vault health, unseal status, auth paths, and critical secrets

High-level pseudocode:

```text
pick snapshot object
download snapshot locally
prepare target Vault node/cluster
ensure restore target is not serving conflicting live writes
run raft snapshot restore
restart or recover Vault as needed
validate auth and secret paths
only then re-enable dependent workloads
```

Conceptual command shape:

```bash
vault operator raft snapshot restore /path/to/vault-<timestamp>.snap
```

Do not treat that as a casual one-liner. In a real incident, document:

- target environment
- chosen snapshot timestamp
- pre-restore Vault health
- post-restore validation results

## Hetzner Server Backup Recovery Model

Hetzner automatic Backups are the coarse recovery layer.

Use them when the problem is:

- node loss
- filesystem corruption
- catastrophic local-path volume loss
- broken machine state beyond normal service-level recovery

Do not use them as the first response for:

- one lost app database row
- one Vault secret mistake
- one bad Kubernetes resource

Those are service-level or Git-level recovery problems, not whole-node problems.

The node-backup recovery model is:

```text
Hetzner server Backup
  -> recover VM state quickly
  -> then validate K3s, Vault, Argo, and workloads
  -> then use service-level restores only if needed
```

## Failure Modes

### Manual job never uploads an object

Likely causes:

- `VaultAuth` not ready
- `backup-storage` secret missing
- Vault policy/role not bootstrapped
- object-storage credentials wrong

Check:

```bash
kubectl -n vault get vaultauth,vaultstaticsecret,secret,cronjob
kubectl -n vault logs job/<manual-job-name>
```

### Vault login works but snapshot fails

Likely causes:

- missing `sys/storage/raft/snapshot` capability
- wrong Vault address
- Vault instance not healthy

### Upload fails after snapshot succeeds

Likely causes:

- bad object-storage endpoint
- wrong access key / secret key
- wrong bucket name

### Restore is attempted casually into the live cluster

This is a process failure, not a tooling failure.

Pause and explicitly decide:

- incident scope
- snapshot choice
- target environment
- rollback path

## Related Documents

- [docs/cluster-data-services-backup-and-restore-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/cluster-data-services-backup-and-restore-playbook.md)
- [docs/tailscale-k3s-admin-access-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/tailscale-k3s-admin-access-playbook.md)
- [HK3S-0017 index](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/29/HK3S-0017--implement-vault-snapshots-and-hetzner-server-backups/index.md)

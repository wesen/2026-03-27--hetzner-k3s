---
Title: Vault snapshot and server backup diary
Ticket: HK3S-0017
Status: active
Topics:
    - vault
    - backup
    - restore
    - hetzner
    - terraform
DocType: reference
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: "Chronological implementation diary for adding Hetzner automatic server Backups and a Vault Raft snapshot pipeline."
LastUpdated: 2026-03-29T18:10:00-04:00
WhatFor: "Use this to continue or review the exact operator trail for HK3S-0017."
WhenToUse: "Read this when implementing or auditing the backup posture for the VM and Vault."
---

# Vault snapshot and server backup diary

## Goal

Add the two missing recovery layers for this single-node platform:

- coarse node recovery through Hetzner server Backups
- service-specific Vault recovery through Raft snapshots uploaded off-cluster

## Step 1: Reconfirm the missing recovery layers and turn them into one explicit ticket

The cluster already had:

- Git as declarative recovery for Terraform and GitOps state
- service-level backups for PostgreSQL, MySQL, and Redis

What it still did not have was:

- Vault-native backup automation
- provider-level full-node backup coverage

The important design clarification at the start of this ticket was that these are not interchangeable:

- VM Backups are not a replacement for Vault snapshots
- Vault snapshots are not a replacement for VM Backups

That is why this ticket explicitly covers both.

### What I did
- Checked the live Vault deployment definition.
- Confirmed Vault uses integrated Raft and AWS KMS auto-unseal.
- Confirmed there was no existing Vault snapshot CronJob or object-storage path in the repo.
- Confirmed the Hetzner server resource did not yet explicitly enable automatic Backups.
- Created HK3S-0017 with a design guide, implementation guide, and concrete task list.

### Why
- The recovery posture needed to be made explicit before implementing more YAML.

### What worked
- The repo already had the right building blocks from HK3S-0009 and HK3S-0003.

### What didn't work
- The earlier Vault docs described snapshots as a future need, but there was no concrete implementation ticket yet.

### What I learned
- By this point in the migration, the missing backup layers are no longer “nice to have.” They are the next obvious operational gap.

### What should be done in the future
- Implement Hetzner automatic Backups first because that is the quickest coarse recovery win.
- Then add the Vault snapshot CronJob in a way that reuses the proven object-storage pattern.

## Step 2: Enable Hetzner automatic Backups on the live server and verify the provider-owned recovery window

The first live implementation slice in this ticket was intentionally the simpler one: turn on Hetzner automatic Backups for the actual K3s server resource. Before changing Terraform, I checked the live provider schema locally with `terraform providers schema -json`. That mattered because I did not want to guess whether `backup_window` was a real configurable argument or just provider output.

The schema confirmed:

- `backups` is a real optional boolean on `hcloud_server`
- `backup_window` exists but is deprecated and computed

So the right implementation was not “add a schedule variable.” The right implementation was:

- add `server_backups_enabled` to [`variables.tf`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/variables.tf)
- wire `backups = var.server_backups_enabled` into [`main.tf`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/main.tf)

I made that change, ran:

- `terraform fmt`
- `terraform validate`
- `terraform plan`
- `terraform apply -auto-approve`

The live plan was exactly what we wanted:

- in-place update of `hcloud_server.node`
- `backups = false -> true`

After apply, `terraform state show hcloud_server.node` confirmed:

- `backups = true`
- `backup_window = "02-06"`

That last part is important operationally. We do not choose the backup window in this repo. Hetzner assigns it, and the provider exposes it back as computed state. So the docs for this ticket need to describe:

- Backups are enabled declaratively
- the exact backup window is provider-owned, not repo-owned

### What I did
- Queried the local Terraform provider schema for `hcloud_server`.
- Added the explicit repo variable for server Backups.
- Enabled `backups` on the live Hetzner server resource.
- Validated the provider-assigned backup window from Terraform state.

### Why
- Whole-node recovery should not remain an implicit manual operator habit when the provider already supports recurring Backups.

### What worked
- The Terraform change was a clean in-place update.
- The provider behavior matched the schema inspection: enablement is configurable, the window is provider-owned.

### What didn't work
- Nothing failed technically here, but it would have been easy to design the wrong interface if I had assumed `backup_window` was still a normal configurable argument.

### What I learned
- For the Hetzner side, “enable Backups” is a small change, but “document what is and is not under repo control” matters just as much as the toggle itself.

### What should be done in the future
- Commit this Terraform slice separately.
- Move to the Vault snapshot pipeline next, because that is now the more important missing recovery layer.

## Step 3: Scaffold the Vault snapshot job around Kubernetes auth and the existing object-storage path

With the Hetzner half in place, I moved to the more interesting part: Vault-native snapshots. Before writing any manifests, I checked the recovery constraints again. The live Vault deployment in [vault.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault.yaml) runs:

- integrated Raft
- local-path PVC
- AWS KMS auto-unseal

That ruled out any fake filesystem-copy design. The right artifact is a real Raft snapshot.

The next design question was authentication. I explicitly did not want to mount the root token into Kubernetes. Instead, I reused the existing Vault Kubernetes auth path already managed by [`bootstrap-vault-kubernetes-auth.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-kubernetes-auth.sh). That led to a clean machine-auth model:

- service account `vault-backup` in namespace `vault`
- Vault policy `vault-backup`
- Vault Kubernetes auth role `vault-backup`
- VSO `VaultAuth` in namespace `vault`

The policy shape I added was intentionally narrow:

- read access to `kv/data/infra/backups/object-storage`
- snapshot access on `sys/storage/raft/snapshot`

I then scaffolded a separate GitOps application rather than trying to wedge extra YAML into the Helm chart source. The new runtime surface is:

- [`gitops/applications/vault-backup.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-backup.yaml)
- [`gitops/kustomize/vault-backup/kustomization.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-backup/kustomization.yaml)
- [`gitops/kustomize/vault-backup/serviceaccount.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-backup/serviceaccount.yaml)
- [`gitops/kustomize/vault-backup/vault-connection.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-backup/vault-connection.yaml)
- [`gitops/kustomize/vault-backup/vault-auth.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-backup/vault-auth.yaml)
- [`gitops/kustomize/vault-backup/backup-storage-vault-static-secret.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-backup/backup-storage-vault-static-secret.yaml)
- [`gitops/kustomize/vault-backup/cronjob.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-backup/cronjob.yaml)

The CronJob uses `alpine:3.22`, installs `aws-cli`, `curl`, `jq`, and `gzip`, logs into Vault with the service account JWT, downloads a Raft snapshot over the HTTP API, compresses it, and uploads it to:

- `s3://scapegoat-k3s-backups/vault/`

I also created the ticket-local scripts:

- [`00-common.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/29/HK3S-0017--implement-vault-snapshots-and-hetzner-server-backups/scripts/00-common.sh)
- [`01-bootstrap-vault-backup-auth.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/29/HK3S-0017--implement-vault-snapshots-and-hetzner-server-backups/scripts/01-bootstrap-vault-backup-auth.sh)
- [`02-trigger-vault-backup-job.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/29/HK3S-0017--implement-vault-snapshots-and-hetzner-server-backups/scripts/02-trigger-vault-backup-job.sh)
- [`03-list-vault-backup-objects.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/29/HK3S-0017--implement-vault-snapshots-and-hetzner-server-backups/scripts/03-list-vault-backup-objects.sh)

Static validation passed:

- `kubectl kustomize gitops/kustomize/vault-backup`
- `bash -n` on all four ticket scripts
- `git diff --check`

### What I did
- Defined the Vault snapshot policy and Kubernetes auth role.
- Added the repo-owned `vault-backup` Argo CD application and Kustomize package.
- Reused the shared object-storage path through a new `vault/` prefix.
- Added replayable ticket-local scripts for the operator workflow.
- Validated the scaffold locally before touching the live cluster.

### Why
- The remote repo needs the full package before Argo can reconcile it.
- Vault backup automation should follow the same reviewable GitOps shape as the rest of the platform.

### What worked
- The existing HK3S-0009 object-storage pattern generalized cleanly to Vault.
- The existing Vault Kubernetes auth bootstrap flow was a good fit for the snapshot job identity.

### What didn't work
- Nothing failed yet in the scaffold itself, but this is exactly the kind of slice where live Vault permissions may still reveal endpoint-specific surprises once the first job runs.

### What I learned
- A separate `vault-backup` application is cleaner than trying to graft extra YAML onto the Helm chart-managed Vault application.

### What should be done in the future
- Commit and push the scaffold.
- Bootstrap the live Vault policy and role.
- Apply the Argo application and run the first manual snapshot job.

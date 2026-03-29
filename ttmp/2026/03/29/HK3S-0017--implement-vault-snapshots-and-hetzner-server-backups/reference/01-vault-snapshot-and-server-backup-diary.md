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
LastUpdated: 2026-03-29T20:15:00-04:00
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

## Step 4: Re-bootstrap the live Vault auth path, sync the backup app, and prove the first snapshot upload

With the scaffold already merged, the next question was whether it would actually run live with the real Vault auth backend and the real object-storage secret. I first reran the ticket bootstrap script against `https://vault.yolo.scapegoat.dev` so I did not have to assume the live `vault-backup` policy and role were still present from the earlier partial pass.

### What I did
- Ran:
  - `VAULT_ADDR=https://vault.yolo.scapegoat.dev bash .../scripts/01-bootstrap-vault-backup-auth.sh`
- Created and refreshed the Argo application:
  - `kubectl apply -f gitops/applications/vault-backup.yaml`
  - annotated the application for a hard refresh
- Verified the synced runtime surface in namespace `vault`:
  - `serviceaccount/vault-backup`
  - `vaultauth/vault-backup`
  - `vaultconnection/vault-connection`
  - `vaultstaticsecret/backup-storage`
  - `secret/backup-storage`
  - `cronjob/vault-backup`
- Triggered the first manual backup run with:
  - `scripts/02-trigger-vault-backup-job.sh`
- Listed the resulting object-storage prefix with:
  - `scripts/03-list-vault-backup-objects.sh`

### Why
- Static YAML validation was not enough. The real question was whether the end-to-end path would work:
  - Kubernetes service account JWT
  - Vault Kubernetes auth login
  - Raft snapshot read
  - gzip
  - Hetzner Object Storage upload

### What worked
- The bootstrap rerun completed cleanly.
- Argo synced the `vault-backup` application successfully.
- The VSO `VaultStaticSecret` reconciled and created `secret/backup-storage`.
- The first manual job completed successfully on the first real attempt.
- The job log reported:
  - `uploaded=vault/vault-20260329T201050Z.snap.gz`
- The object-storage listing showed:
  - `2026-03-29 16:10:51     134956 vault/vault-20260329T201050Z.snap.gz`

### What didn't work
- The very first direct `kubectl get vaultstaticsecret backup-storage` I ran immediately after creating the application returned `NotFound`, but that turned out not to be a real failure. Argo had not finished materializing the resource yet. A second check a few seconds later showed the CR and the synced Kubernetes secret normally.

### What I learned
- The live Vault snapshot path is considerably cleaner than the earlier MySQL backup rollout. No policy or endpoint surprises surfaced once the runtime surface existed.
- The one operational gotcha is timing: immediately after Argo app creation, give the secrets operator a few seconds to reconcile before deciding something is missing.

### What should be done in the future
- Write the permanent operator playbook next so the restore model and Hetzner whole-node backup layer are not trapped inside the ticket diary.

## Step 5: Decide the restore stance and write the permanent operator playbook

Once the first artifact existed, the remaining question was not “can we back up Vault?” It was “what restore stance is safe enough to document honestly for this environment?”

### What I did
- Wrote the top-level operator document:
  - [`docs/vault-snapshot-and-server-backup-playbook.md`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/vault-snapshot-and-server-backup-playbook.md)
- Updated the repo README to link the new playbook.
- Updated the ticket index, tasks, and changelog to reflect the now-proven live state.
- Explicitly decided that a Vault scratch restore drill should stay documented-only for now.

### Why
- Vault restore is more dangerous than the shared data-service scratch restores.
- This cluster is single-node and the live Vault instance is itself part of the control plane.
- I did not want to produce a fake “validated restore” claim by improvising a risky live restore exercise.

### What worked
- The repo now has a stable operator-facing document for:
  - enabling and understanding Hetzner server Backups
  - re-running the Vault snapshot job
  - verifying off-cluster artifacts
  - understanding the restore decision boundary

### What didn't work
- No safe live scratch restore path was implemented in this slice, by design.

### What I learned
- The honest and correct operational stance is:
  - snapshot creation is validated live
  - restore procedure is documented
  - restore drill remains a separate deliberate future activity if the platform design makes it safer

### What should be done in the future
- Re-run `docmgr doctor`
- commit and push the final HK3S-0017 closeout

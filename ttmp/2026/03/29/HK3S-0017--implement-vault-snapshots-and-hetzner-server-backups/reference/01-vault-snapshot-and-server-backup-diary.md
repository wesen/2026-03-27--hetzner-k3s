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

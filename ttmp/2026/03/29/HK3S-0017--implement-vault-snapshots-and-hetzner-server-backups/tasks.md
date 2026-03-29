# Tasks

## Phase 1: Scope and recovery model

- [x] Confirm the two separate recovery layers to add: Vault snapshots and Hetzner server backups
- [x] Decide that Hetzner automatic Backups, not ad hoc snapshots, are the right coarse full-node mechanism
- [x] Decide that Vault needs a service-specific Raft snapshot pipeline rather than relying on VM backups alone

## Phase 2: Ticket documentation

- [x] Add the ticket index, design guide, implementation guide, diary, and task list
- [x] Keep the diary updated as each implementation slice lands
- [x] Add replayable operator scripts under the ticket `scripts/` directory

## Phase 3: Hetzner server backup implementation

- [x] Inspect the current `hcloud_server` schema and repo Terraform constraints
- [x] Add Terraform configuration to enable Hetzner automatic Backups on the K3s server
- [x] Add any needed Terraform variable or operator-facing comment so the backup posture is explicit in the repo
- [x] Run `terraform plan` and `terraform apply`
- [x] Validate from Terraform state or Hetzner API output that server backups are enabled

## Phase 4: Vault snapshot architecture

- [x] Define the Vault policy needed for snapshot creation
- [x] Define the Kubernetes auth role and service-account boundary for the snapshot job
- [x] Decide how the Vault snapshot job consumes object-storage credentials
- [x] Reuse the existing Hetzner Object Storage bucket through a new `vault/` prefix

## Phase 5: Vault snapshot implementation

- [x] Add the Vault policy and Kubernetes auth role for the snapshot job
- [x] Add replayable ticket scripts for seeding any Vault-side state needed by the snapshot job
- [x] Add the GitOps manifests for the Vault snapshot job runtime surface
- [x] Add a `CronJob` that authenticates through Vault Kubernetes auth, creates a Raft snapshot, and uploads it to object storage
- [x] Ensure the job fails closed if authentication or snapshot creation fails

## Phase 6: Validation

- [x] Run the Vault snapshot job manually once
- [x] Verify that a `vault/` artifact lands in Hetzner Object Storage
- [x] Inspect the snapshot artifact size and naming shape
- [ ] Re-run `docmgr doctor`

## Phase 7: Restore and operator docs

- [x] Write the operator playbook for Vault snapshot restore and Hetzner server-backup usage
- [x] Decide whether a safe Vault scratch restore drill is feasible in this environment or should stay documented-only for now
- [x] Update the main repo docs if the new backup posture should be visible outside the ticket

## Phase 8: Closeout

- [x] Update the diary, changelog, and ticket index with the final live state
- [ ] Commit and push the Terraform and GitOps checkpoints separately when that improves reviewability

---
Title: Vault snapshot and server backup implementation guide
Ticket: HK3S-0017
Status: active
Topics:
    - vault
    - backup
    - restore
    - hetzner
    - terraform
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/main.tf
      Note: Hetzner server resource
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault.yaml
      Note: Live Vault deployment definition
ExternalSources: []
Summary: "Detailed implementation guide for adding Hetzner server backups and a Vault Raft snapshot upload pipeline to this K3s repo."
---

# Vault snapshot and server backup implementation guide

## Goal

Implement both missing recovery layers for this cluster:

- Hetzner automatic Backups on the full VM
- Vault Raft snapshots uploaded off-cluster

The design intent is to make these look like the rest of the platform:

- infrastructure changes in Terraform
- cluster runtime changes in GitOps
- runtime credentials through Vault and VSO
- replayable operator steps in ticket-local scripts

## Step 1: Enable Hetzner automatic Backups in Terraform

The Hetzner side should be the simpler half of this ticket.

Inspect the `hcloud_server` resource in [main.tf](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/main.tf), then add the provider-level automatic Backups setting there.

The intended shape is:

```hcl
resource "hcloud_server" "node" {
  ...
  backups = true
}
```

If a variable is added, it should make the behavior explicit rather than hiding it.

After editing:

```bash
terraform plan
terraform apply
```

Then verify from Terraform state or provider output that the server now has Backups enabled.

## Step 2: Reuse the shared object-storage path

Do not create a second backup bucket for Vault unless a hard isolation requirement appears.

Reuse:

- the existing Hetzner Object Storage bucket from HK3S-0009
- the shared Vault path `kv/infra/backups/object-storage`

but add a new prefix:

- `vault/`

That keeps the operator model simple:

- one bucket
- one credential set
- service-specific prefixes

## Step 3: Define the Vault auth boundary for the snapshot job

The Vault backup job should not use the root token.

Instead:

1. create a dedicated Kubernetes service account in `vault`
2. create a dedicated Vault policy for snapshot creation
3. bind that service account to a Kubernetes auth role

The CronJob should:

- read its JWT from the service account token mount
- log in to Vault using `auth/kubernetes/login`
- receive a scoped client token
- use that token to create the Raft snapshot

This is the same machine-auth model the repo already uses elsewhere.

## Step 4: Add the GitOps runtime surface

The Vault namespace should get:

- service account
- optional VSO `VaultStaticSecret` for object-storage creds
- CronJob manifest

The CronJob contract should be:

1. authenticate to Vault
2. create a Raft snapshot
3. verify the artifact is non-empty
4. upload to object storage
5. exit non-zero on any failure

## Step 5: Keep the operator steps replayable

Add ticket-local scripts for:

- any Vault-side bootstrap needed for the snapshot policy/role
- manual triggering or validation of the Vault backup path
- listing the resulting `vault/` artifacts if needed

Those scripts should live in:

- [`scripts/`](../scripts)

and should follow the numbered pattern already used in HK3S-0009.

## Step 6: Validate the backup path

Run the snapshot job manually once. Validation should include:

- the job succeeds
- a `vault/` object lands in the bucket
- the artifact is non-empty
- the naming convention is stable and timestamped

If a restore drill is safe, do one. If not, document the restore procedure carefully and capture why the drill is deferred.

## Step 7: Write the operator docs

After the implementation is real, write the operator docs based on the actual live path:

- how Vault snapshots are created
- where they land
- what Hetzner Backups cover
- when to use VM recovery vs Vault recovery

The docs should make it impossible to confuse:

- “restore the full node”
- “restore Vault”
- “restore a database”

## Review checklist

The implementation is ready for review when:

- Terraform changes are isolated and reviewable
- GitOps Vault backup manifests are isolated and reviewable
- ticket scripts reproduce the operator steps
- the diary records both the happy path and any failures
- `docmgr doctor` passes

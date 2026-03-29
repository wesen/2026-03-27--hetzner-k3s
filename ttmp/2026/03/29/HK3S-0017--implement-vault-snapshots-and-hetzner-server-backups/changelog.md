# Changelog

## 2026-03-29

- Initial workspace created
- Defined the scope as two complementary recovery layers: Hetzner automatic server Backups and Vault Raft snapshots
- Added the ticket index, design guide, implementation guide, diary, and concrete task list
- Enabled Hetzner automatic Backups on the live `hcloud_server.node` resource and verified provider-owned backup window `02-06`
- Added the `vault-backup` GitOps scaffold, Vault policy and Kubernetes auth role, and replayable ticket-local scripts for the snapshot operator path
- Re-bootstrapped the live Vault Kubernetes auth path for the `vault-backup` role and policy
- Applied and synced the `vault-backup` Argo application into the cluster
- Verified the `backup-storage` `VaultStaticSecret` and resulting Kubernetes `Secret`
- Ran the first manual Vault snapshot job successfully
- Verified the first off-cluster object `vault/vault-20260329T201050Z.snap.gz` with size `134956`
- Added the permanent operator playbook for Vault snapshots and Hetzner server Backups
- Explicitly documented that Vault scratch restore remains a documented-only procedure for now

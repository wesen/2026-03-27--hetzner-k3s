# Changelog

## 2026-03-29

- Initial workspace created
- Defined the scope as two complementary recovery layers: Hetzner automatic server Backups and Vault Raft snapshots
- Added the ticket index, design guide, implementation guide, diary, and concrete task list
- Enabled Hetzner automatic Backups on the live `hcloud_server.node` resource and verified provider-owned backup window `02-06`
- Added the `vault-backup` GitOps scaffold, Vault policy and Kubernetes auth role, and replayable ticket-local scripts for the snapshot operator path

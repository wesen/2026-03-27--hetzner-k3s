# Changelog

## 2026-03-27

- Initial workspace created
- Added the deferred implementation outline and task plan so the future Keycloak-on-K3s move is queued explicitly instead of living as verbal follow-up

## 2026-03-28

- Updated the deferred Keycloak-on-K3s plan now that Vault, VSO, the first migrated app, and shared PostgreSQL are all live; marked the platform-prerequisite task complete and recorded that shared PostgreSQL is now the preferred Keycloak backing-store candidate when this ticket is activated
- Added the reusable Vault-backed PostgreSQL bootstrap Job pattern doc, a concrete Keycloak-on-K3s implementation design doc, and a live diary so HK3S-0008 can proceed task by task instead of remaining a vague deferred note
- Added the initial Keycloak package scaffold, including Vault/VSO secret wiring, a PostgreSQL bootstrap `PreSync` Job, the parallel-host ingress, and local bootstrap/validation helpers
- Seeded the live Vault data, fixed the bootstrap Job ordering bug by moving it out of `PreSync` hook mode, recovered the wedged Argo application state, and brought `https://auth.yolo.scapegoat.dev` up to `Synced Healthy` with successful bootstrap-admin login validation
- Added the Terraform `k3s-parallel` environment for the `infra` realm, recreated the `infra` realm and `vault-oidc` client against `https://auth.yolo.scapegoat.dev`, repointed Vault `oidc/` at the new issuer, and validated browser login to both Vault and the Keycloak Account Console
- Added [validate-keycloak-backup-restore.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-keycloak-backup-restore.sh) and proved logical PostgreSQL dump/restore for the `keycloak` database into a scratch database before leaving the external deployment as the rollback path
- Added the Terraform `k3s-parallel` environment for the `coinvault` realm, recreated the `coinvault-web` client against `https://auth.yolo.scapegoat.dev`, updated the CoinVault and MySQL IDE deployments plus the Vault-backed runtime secret to use the new issuer, and validated real browser login to CoinVault
- Removed the legacy `demo-stack` Argo application from the cluster and deleted the `gitops/kustomize/demo-stack` package from the repo now that it is no longer needed as a placeholder workload

## 2026-03-29

- Added Terraform-managed bootstrap users for the K3s `coinvault` realm: `wesen` and `clint`
- Generated local non-temporary bootstrap passwords in ignored Terraform input, applied the CoinVault `k3s-parallel` environment, and captured the resulting Keycloak subject IDs
- Added the replayable ticket-local script [01-store-coinvault-keycloak-bootstrap-users-in-vault.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0008--move-shared-keycloak-onto-k3s-under-argo-cd/scripts/01-store-coinvault-keycloak-bootstrap-users-in-vault.sh) to escrow those bootstrap credentials into `vault.yolo.scapegoat.dev`
- Stored the CoinVault bootstrap credentials in Vault under `kv/apps/coinvault/prod/keycloak-users/wesen` and `kv/apps/coinvault/prod/keycloak-users/clint`, then validated the stored usernames and Keycloak subject IDs without printing the passwords

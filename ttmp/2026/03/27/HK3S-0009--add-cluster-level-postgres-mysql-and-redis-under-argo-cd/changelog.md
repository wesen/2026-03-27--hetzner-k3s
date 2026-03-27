# Changelog

## 2026-03-27

- Initial workspace created
- Added the deferred implementation outline and task plan for future shared cluster data services
- Step 1: reactivated the ticket as a MySQL-first slice after the CoinVault migration hit a Coolify-only MySQL hostname, and recorded the new decision to prove shared MySQL before revisiting Postgres or Redis
- Step 2: added the MySQL scaffold, including the Bitnami-chart Argo CD application, Vault Kubernetes-auth policy and role for the MySQL service account, and helper scripts to bootstrap Vault credentials and validate the cluster-local MySQL deployment
- Step 3: statically validated the MySQL scaffold, confirmed the ticket passes `docmgr doctor`, and explicitly isolated unrelated CoinVault and Terraform carry-over changes so the MySQL checkpoint can stay reviewable

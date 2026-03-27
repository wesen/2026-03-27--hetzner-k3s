# Changelog

## 2026-03-27

- Initial workspace created
- Added the deferred implementation outline and task plan for future shared cluster data services
- Step 1: reactivated the ticket as a MySQL-first slice after the CoinVault migration hit a Coolify-only MySQL hostname, and recorded the new decision to prove shared MySQL before revisiting Postgres or Redis
- Step 2: added the MySQL scaffold, including the Bitnami-chart Argo CD application, Vault Kubernetes-auth policy and role for the MySQL service account, and helper scripts to bootstrap Vault credentials and validate the cluster-local MySQL deployment
- Step 3: statically validated the MySQL scaffold, confirmed the ticket passes `docmgr doctor`, and explicitly isolated unrelated CoinVault and Terraform carry-over changes so the MySQL checkpoint can stay reviewable
- Step 4: began the live rollout, bootstrapped the Vault policy/role and secret path successfully, hit a missing execute bit on the helper scripts, then discovered the external Bitnami chart path was not operational in practice because the published chart repo lagged the GitHub chart tree and referenced a non-existent container image tag; pivoted to repo-managed Kustomize manifests using the official `mysql:8.4` image while keeping the same Vault/VSO secret contract

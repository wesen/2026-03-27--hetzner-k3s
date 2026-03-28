# Changelog

## 2026-03-27

- Initial workspace created
- Added the deferred implementation outline and task plan for future shared cluster data services
- Step 1: reactivated the ticket as a MySQL-first slice after the CoinVault migration hit a Coolify-only MySQL hostname, and recorded the new decision to prove shared MySQL before revisiting Postgres or Redis
- Step 2: added the MySQL scaffold, including the Bitnami-chart Argo CD application, Vault Kubernetes-auth policy and role for the MySQL service account, and helper scripts to bootstrap Vault credentials and validate the cluster-local MySQL deployment
- Step 3: statically validated the MySQL scaffold, confirmed the ticket passes `docmgr doctor`, and explicitly isolated unrelated CoinVault and Terraform carry-over changes so the MySQL checkpoint can stay reviewable
- Step 4: began the live rollout, bootstrapped the Vault policy/role and secret path successfully, hit a missing execute bit on the helper scripts, then discovered the external Bitnami chart path was not operational in practice because the published chart repo lagged the GitHub chart tree and referenced a non-existent container image tag; pivoted to repo-managed Kustomize manifests using the official `mysql:8.4` image while keeping the same Vault/VSO secret contract
- Step 5: pushed the Kustomize pivot, deleted the failed chart-created StatefulSet so Argo could recreate it from the repo-owned spec, then aligned the StatefulSet manifest with Kubernetes-defaulted fields until Argo reported `Synced Healthy`
- Step 6: validated the final MySQL service end to end, including SQL execution inside the server pod and a one-shot client pod reaching `mysql.mysql.svc.cluster.local` as the application user `coinvault_ro`

## 2026-03-28

- Step 7: reactivated HK3S-0009 for shared PostgreSQL and Redis, added the follow-on design doc and task phases, and scaffolded the Vault, Argo, Kustomize, bootstrap, and validation artifacts for both services

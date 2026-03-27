# Changelog

## 2026-03-27

- Initial workspace created
- Step 1: compared the initial candidate apps, rejected hair-booking as the first runtime target because it is not yet a real deployable hosted service, and selected CoinVault as the first K3s migration target with VSO-backed runtime secrets plus mounted Pinocchio config
- Step 2: translated the CoinVault hosted runtime contract into repo-managed K3s manifests, including the Argo CD application, Kustomize package, PVC, ingress, VSO secret sync resources, and helper scripts for seeding Vault, importing the image, and validating the rollout
- Step 3: cut the K3s Vault runtime secret over to the cluster-local MySQL endpoint, confirmed the parallel Keycloak callback/origin path was already live, and committed the Terraform repo so Git matched reality
- Step 4: fixed the CoinVault image-import path so it could build from the app repo on this workstation without depending on local `replace` targets, then built and imported `coinvault:hk3s-0007` into the K3s node
- Step 5: created the live Argo CD application, resolved an Argo sync-wave deadlock caused by a `WaitForFirstConsumer` PVC, and brought the deployment to `Synced Healthy`
- Step 6: validated the live K3s deployment at `https://coinvault.yolo.scapegoat.dev`, including VSO secret presence, healthy startup logs, database connectivity, and OIDC login redirect behavior

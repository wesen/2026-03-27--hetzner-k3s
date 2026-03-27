# Changelog

## 2026-03-27

- Initial workspace created
- Step 1: compared the initial candidate apps, rejected hair-booking as the first runtime target because it is not yet a real deployable hosted service, and selected CoinVault as the first K3s migration target with VSO-backed runtime secrets plus mounted Pinocchio config
- Step 2: translated the CoinVault hosted runtime contract into repo-managed K3s manifests, including the Argo CD application, Kustomize package, PVC, ingress, VSO secret sync resources, and helper scripts for seeding Vault, importing the image, and validating the rollout
- Step 3: cut the K3s Vault runtime secret over to the cluster-local MySQL endpoint, confirmed the parallel Keycloak callback/origin path was already live, and committed the Terraform repo so Git matched reality
- Step 4: fixed the CoinVault image-import path so it could build from the app repo on this workstation without depending on local `replace` targets, then built and imported `coinvault:hk3s-0007` into the K3s node
- Step 5: created the live Argo CD application, resolved an Argo sync-wave deadlock caused by a `WaitForFirstConsumer` PVC, and brought the deployment to `Synced Healthy`
- Step 6: validated the live K3s deployment at `https://coinvault.yolo.scapegoat.dev`, including VSO secret presence, healthy startup logs, database connectivity, and OIDC login redirect behavior
- Step 7: debugged post-rollout runtime config drift, disabled Kubernetes service-link env injection for CoinVault, hardened the entrypoint against inherited port variables, fixed CoinVault profile-registry parsing for merged env plus flag values, rebuilt the image, and verified the live pod now reports `profile_registries=/run/secrets/pinocchio/profiles.yaml`
- Step 8: imported the local `gec_dev` MySQL dataset from the repo-local CoinVault compose service into the cluster `gec` schema, verified `products`, `orders`, and `metals` row counts on K3s, and confirmed the `coinvault_ro` runtime user can read the imported tables

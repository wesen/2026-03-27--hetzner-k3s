# Changelog

## 2026-03-27

- Initial workspace created
- Step 1: compared the initial candidate apps, rejected hair-booking as the first runtime target because it is not yet a real deployable hosted service, and selected CoinVault as the first K3s migration target with VSO-backed runtime secrets plus mounted Pinocchio config
- Step 2: translated the CoinVault hosted runtime contract into repo-managed K3s manifests, including the Argo CD application, Kustomize package, PVC, ingress, VSO secret sync resources, and helper scripts for seeding Vault, importing the image, and validating the rollout

# Changelog

## 2026-03-27

- Initial workspace created
- Step 1: Reused the existing shared `infra` Keycloak realm and `vault-oidc` client model instead of creating a second K3s-only operator identity stack
- Step 2: Extended the shared Keycloak client to allow the `vault.yolo.scapegoat.dev` UI callback and committed that change in the Terraform repo (`666f4be`)
- Step 3: Added the K3s-side OIDC bootstrap and validation scaffold, including operator policies, scripts, playbook, and diary (`67c5871`)
- Step 4: Applied the live Vault `oidc/` auth backend, `operators` role, operator policies, and external group aliases on the K3s Vault instance
- Step 5: Validated positive browser and CLI login for an `infra-admins` user and negative CLI rejection for a user outside the operator groups

# Changelog

## 2026-04-26

- Initial workspace created.
- Added Terraform code in `keycloak/apps/infra-access/envs/k3s-parallel` to look up the existing `wesen` user and add additive membership in `infra-admins`.
- Added variables `manage_wesen_vault_admin_membership` and `wesen_operator_username` plus an output recording whether the membership is managed.
- Ran Terraform validation, plan, and apply with Keycloak bootstrap-admin credentials loaded from the k3s Secret without printing the password.
- Applied successfully: `1 added, 2 changed, 0 destroyed`; the added resource is `keycloak_user_groups.wesen_vault_admin[0]`.
- Verified through the Keycloak Admin API that `wesen` is now in `infra-admins`.

## 2026-04-26

Implemented Terraform-managed wesen membership in infra-admins, applied it to auth.yolo.scapegoat.dev, and verified Keycloak group readback.

### Related Files

- /home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/k3s-parallel/main.tf — Implemented membership resource


## 2026-04-26

Copied the Obsidian textbook-style Vault admin access report back into the HK3S-0026 ticket as a reference doc.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/04/26/HK3S-0026--manage-infra-vault-operator-user-membership-in-terraform/reference/02-project-report-terraform-managed-vault-admin-access-through-keycloak-oidc.md — Project report copied from Obsidian


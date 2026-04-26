# Tasks

## TODO

- [x] Create HK3S-0026 ticket in the k3s docmgr root.
- [x] Inspect the Keycloak Terraform provider schema for existing-user membership management.
- [x] Add Terraform data source lookup for the existing `wesen` user.
- [x] Add additive `keycloak_user_groups` membership in `infra-admins`.
- [x] Run `terraform fmt` and `terraform validate`.
- [x] Plan and apply the Terraform change against `auth.yolo.scapegoat.dev`.
- [x] Verify Keycloak Admin API readback shows `wesen` in `infra-admins`.
- [ ] Retry `vault login -method=oidc role=operators` as `wesen` and confirm `identity_policies` includes `admin`.
- [ ] Seed the Discord UI showcase bot runtime secret into Vault.

# Changelog

## 2026-04-01

- Initial workspace created
- Scoped the ticket to a Kubernetes-authenticated Keycloak SMTP reconciler for `hair-booking`
- Added the task plan covering Vault policy/role wiring, the reconciler runtime, validation, and diary updates
- Implemented the `hair-booking` SMTP reconciler in the Keycloak Kustomize package and committed it as `f1612d2`
- Validated the reconciler end-to-end against `auth.yolo.scapegoat.dev`, including an `updated` run and a no-op `in-sync` rerun
- Added the K3s platform doc for the realm-side SMTP reconciler pattern and updated the app-side playbook to describe the new steady-state split

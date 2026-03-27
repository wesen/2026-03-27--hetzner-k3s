# Tasks

## Phase 1: Design and dependency confirmation

- [x] Confirm whether the K3s Vault should reuse the existing `infra` Keycloak realm or create a new app/client boundary
- [x] Confirm the target callback URLs for UI and CLI login on `vault.yolo.scapegoat.dev`
- [x] Confirm the intended operator policy groups:
  admin and read-only

## Phase 2: Repo-managed identity and operator docs

- [x] Add the Keycloak-side plan and any repo-side configuration artifacts needed for the client
- [x] Add the Vault-side operator playbook for OIDC login on the new hostname
- [x] Document break-glass posture and how the K3s Vault root token should no longer be normal operator workflow

## Phase 3: Live implementation

- [x] Provision or adapt the Keycloak OIDC client for the K3s Vault hostname
- [x] Enable `oidc/` on the K3s Vault instance
- [x] Configure the OIDC backend and the `operators` role
- [x] Create or map the operator policies and external identity groups

## Phase 4: Validation

- [x] Validate UI login through `vault.yolo.scapegoat.dev`
- [x] Validate CLI login through `vault login -method=oidc role=operators`
- [x] Validate group-based policy admission and rejection

## Phase 5: Handoff

- [x] Record the final operator playbook and failure signatures
- [x] Validate the ticket with `docmgr doctor`

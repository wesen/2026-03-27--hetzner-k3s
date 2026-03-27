# Tasks

## Phase 1: Design and dependency confirmation

- [ ] Confirm whether the K3s Vault should reuse the existing `infra` Keycloak realm or create a new app/client boundary
- [ ] Confirm the target callback URLs for UI and CLI login on `vault.yolo.scapegoat.dev`
- [ ] Confirm the intended operator policy groups:
  admin and read-only

## Phase 2: Repo-managed identity and operator docs

- [ ] Add the Keycloak-side plan and any repo-side configuration artifacts needed for the client
- [ ] Add the Vault-side operator playbook for OIDC login on the new hostname
- [ ] Document break-glass posture and how the K3s Vault root token should no longer be normal operator workflow

## Phase 3: Live implementation

- [ ] Provision or adapt the Keycloak OIDC client for the K3s Vault hostname
- [ ] Enable `oidc/` on the K3s Vault instance
- [ ] Configure the OIDC backend and the `operators` role
- [ ] Create or map the operator policies and external identity groups

## Phase 4: Validation

- [ ] Validate UI login through `vault.yolo.scapegoat.dev`
- [ ] Validate CLI login through `vault login -method=oidc role=operators`
- [ ] Validate group-based policy admission and rejection

## Phase 5: Handoff

- [ ] Record the final operator playbook and failure signatures
- [ ] Validate the ticket with `docmgr doctor`

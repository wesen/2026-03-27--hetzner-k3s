# Tasks

## Phase 1: Design confirmation

- [x] Confirm VSO is the preferred first secret-consumption path over Vault Agent injection for this cluster
- [x] Confirm the namespace and service account model for the first sync test
- [x] Confirm the CRD layout and Argo CD packaging strategy

## Phase 2: Repo-managed deployment scaffold

- [x] Add the Argo CD `Application` for Vault Secrets Operator
- [x] Add the first `VaultConnection` and `VaultAuth` definitions
- [x] Add the smoke `VaultStaticSecret` and destination Kubernetes `Secret` contract
- [x] Document the operator flow and validation steps

## Phase 3: Live deployment

- [ ] Deploy VSO into the cluster through Argo CD
- [ ] Apply the first `VaultConnection` and `VaultAuth`
- [ ] Seed or verify the source secret path in Vault
- [ ] Apply the smoke `VaultStaticSecret`

## Phase 4: Validation

- [ ] Confirm the destination Kubernetes `Secret` is created
- [ ] Confirm updates in Vault propagate to the destination secret
- [ ] Confirm auth failures and policy denials are legible when misconfigured

## Phase 5: Handoff

- [ ] Record the VSO operating model and next limitations
- [ ] Validate the ticket with `docmgr doctor`

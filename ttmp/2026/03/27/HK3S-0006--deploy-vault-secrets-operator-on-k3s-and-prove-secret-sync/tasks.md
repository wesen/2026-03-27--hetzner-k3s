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

- [x] Deploy VSO into the cluster through Argo CD
- [x] Apply the first `VaultConnection` and `VaultAuth`
- [x] Seed or verify the source secret path in Vault
- [x] Apply the smoke `VaultStaticSecret`

## Phase 4: Validation

- [x] Confirm the destination Kubernetes `Secret` is created
- [x] Confirm updates in Vault propagate to the destination secret
- [x] Confirm auth failures and policy denials are legible when misconfigured

## Phase 5: Handoff

- [x] Record the VSO operating model and next limitations
- [x] Validate the ticket with `docmgr doctor`
- [x] Upload the ticket bundle to reMarkable

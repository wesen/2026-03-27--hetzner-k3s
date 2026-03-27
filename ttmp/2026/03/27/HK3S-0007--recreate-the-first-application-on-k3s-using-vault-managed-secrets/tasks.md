# Tasks

## Phase 1: Choose the first app intentionally

- [x] Compare migration candidates:
  CoinVault, hair-booking, and any smaller internal service that depends on fewer external systems
- [x] Score the candidates by:
  secret complexity, data dependencies, auth complexity, blast radius, and validation ease
- [x] Pick the first migration target and record why

## Phase 2: Application secret and runtime contract

- [x] Inventory the chosen app’s current runtime env and Vault dependencies
- [x] Decide whether the app should consume Vault via VSO-backed Kubernetes `Secret`, direct Vault API login, or another path
- [x] Map current secrets to the new `kv/apps/<app>/<env>/...` convention

## Phase 3: Repo-managed deployment work

- [x] Add the Argo CD application and Kubernetes manifests for the chosen app
- [x] Add the service account and Vault role/policy bindings the app needs
- [x] Add ingress, persistence, and dependency wiring as needed

## Phase 4: Live migration

- [ ] Seed the required Vault secrets
- [ ] Deploy the app on K3s
- [ ] Validate health, login/user flow, and secret consumption
- [ ] Compare behavior to the current deployment

## Phase 5: Handoff

- [ ] Record cutover options and rollback boundaries
- [ ] Validate the ticket with `docmgr doctor`

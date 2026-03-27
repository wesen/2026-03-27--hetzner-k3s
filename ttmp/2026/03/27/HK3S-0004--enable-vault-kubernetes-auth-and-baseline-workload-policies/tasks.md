# Tasks

## Phase 1: Scope and design confirmation

- [x] Confirm the auth design for this cluster:
  Vault uses its own in-cluster service account token as the reviewer JWT source; workloads do not need `system:auth-delegator`
- [x] Confirm the first baseline role set:
  smoke test, `coinvault-prod`, and `hair-booking-prod`
- [x] Confirm the secret path convention for K3s workloads:
  `kv/apps/<app>/<env>/...`

## Phase 2: Repo-managed bootstrap scaffold

- [x] Add the Vault policy files for the smoke workload and the first baseline application roles
- [x] Add the operator bootstrap script that enables/configures Kubernetes auth and writes policies and roles
- [x] Add the validation script that logs in with a Kubernetes service account JWT and proves both allow and deny behavior
- [x] Add the Kubernetes manifests for the smoke-test namespace/service account and verify the Vault reviewer RBAC already exists
- [x] Update ticket docs and top-level repo docs so the operator flow is discoverable

## Phase 3: Live cluster and Vault configuration

- [x] Apply the Kubernetes manifests needed for the smoke namespace/service account
- [x] Enable or verify the `kv/` secrets engine at the intended path
- [x] Enable and configure `auth/kubernetes` on the live Vault instance
- [x] Write the baseline policies and roles to the live Vault instance
- [x] Seed at least one smoke secret under the new path convention

## Phase 4: Validation

- [x] Validate a smoke service account can authenticate against `auth/kubernetes/login`
- [x] Validate the smoke workload can read only its allowed secret path
- [x] Validate access is denied outside the assigned policy subtree
- [x] Record the exact commands and expected outputs in the diary

## Phase 5: Handoff

- [x] Record the next-ticket dependencies:
  OIDC operator login, Vault Secrets Operator, and first app recreation
- [x] Validate the ticket with `docmgr doctor`
- [x] Commit the work in focused checkpoints

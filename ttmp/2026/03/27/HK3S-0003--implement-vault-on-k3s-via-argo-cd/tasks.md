# Tasks

## Phase 1: Ticket setup and execution plan

- [x] Refine scope: recreate Vault deployment on K3s first; do not cut over or dismantle the Coolify deployment in this ticket
- [x] Create implementation ticket `HK3S-0003`
- [x] Create the implementation playbook and diary docs
- [x] Write the detailed ordered task list for execution

## Phase 2: Repo-managed Vault deployment scaffold

- [x] Add a repo-managed Argo CD `Application` for Vault using the official HashiCorp Helm chart
- [x] Choose and encode the first-deploy values:
  single replica, Raft storage, `local-path`, Traefik ingress, cert-manager TLS, AWS KMS auto-unseal env injection
- [x] Add a local bootstrap script to create the non-git Kubernetes secret for AWS KMS credentials
- [x] Update repo docs so the new Vault application and bootstrap workflow are discoverable

## Phase 3: First live deployment

- [x] Create the `vault` namespace bootstrap secret in the live cluster
- [x] Apply the Argo CD `Application` and wait for the Vault pods/services/ingress to converge
- [x] Verify pod scheduling, PVC binding, ingress creation, and public health/UI reachability on `vault.yolo.scapegoat.dev`

## Phase 4: Initial Vault bring-up

- [x] Initialize the new K3s Vault exactly once
- [x] Store recovery material outside git and outside the server
- [x] Verify that the K3s Vault restarts unsealed via AWS KMS

## Phase 5: Post-deploy handoff for later tickets

- [x] Record the live deployment outputs and operator commands in the ticket docs
- [x] Define the next implementation tickets:
  Keycloak OIDC on the new hostname, Kubernetes auth, Vault Secrets Operator, first app secret recreation
- [x] Validate the ticket with `docmgr doctor`
- [x] Commit the implementation work in focused checkpoints as tasks complete

# Tasks

## Phase 1: Ticket setup and execution plan

- [x] Refine scope: recreate Vault deployment on K3s first; do not cut over or dismantle the Coolify deployment in this ticket
- [x] Create implementation ticket `HK3S-0003`
- [x] Create the implementation playbook and diary docs
- [x] Write the detailed ordered task list for execution

## Phase 2: Repo-managed Vault deployment scaffold

- [ ] Add a repo-managed Argo CD `Application` for Vault using the official HashiCorp Helm chart
- [ ] Choose and encode the first-deploy values:
  single replica, Raft storage, `local-path`, Traefik ingress, cert-manager TLS, AWS KMS auto-unseal env injection
- [ ] Add a local bootstrap script to create the non-git Kubernetes secret for AWS KMS credentials
- [ ] Update repo docs so the new Vault application and bootstrap workflow are discoverable

## Phase 3: First live deployment

- [ ] Create the `vault` namespace bootstrap secret in the live cluster
- [ ] Apply the Argo CD `Application` and wait for the Vault pods/services/ingress to converge
- [ ] Verify pod scheduling, PVC binding, ingress creation, and public health/UI reachability on `vault.yolo.scapegoat.dev`

## Phase 4: Initial Vault bring-up

- [ ] Initialize the new K3s Vault exactly once
- [ ] Store recovery material outside git and outside the server
- [ ] Verify that the K3s Vault restarts unsealed via AWS KMS

## Phase 5: Post-deploy handoff for later tickets

- [ ] Record the live deployment outputs and operator commands in the ticket docs
- [ ] Define the next implementation tickets:
  Keycloak OIDC on the new hostname, Kubernetes auth, Vault Secrets Operator, first app secret recreation
- [ ] Validate the ticket with `docmgr doctor`
- [ ] Commit the implementation work in focused checkpoints as tasks complete

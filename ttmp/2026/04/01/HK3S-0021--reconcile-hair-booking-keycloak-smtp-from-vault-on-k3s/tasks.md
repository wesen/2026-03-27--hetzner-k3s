# Tasks

## Completed

- [x] Create `HK3S-0021` ticket workspace
- [x] Add the diary document

## Implementation Queue

### Phase 1: Ticket and scope setup

- [x] Record the current SMTP sync boundary and target design in the ticket
- [x] Add a concrete execution task list for the reconciler work

### Phase 2: Vault and auth wiring

- [x] Add a dedicated Kubernetes Vault policy for the SMTP reconciler
- [x] Add a dedicated Kubernetes Vault role bound to the reconciler service account
- [x] Add the reconciler service account and `VaultAuth` resources in the keycloak namespace
- [x] Add a `VaultStaticSecret` that mirrors `kv/apps/hair-booking/prod/ses` into the keycloak namespace

### Phase 3: Reconciler runtime

- [x] Add the reconciler script ConfigMap
- [x] Add the CronJob or Job manifest that runs the reconciliation
- [x] Ensure the job reads admin creds and SMTP material from namespace-local Kubernetes secrets only
- [x] Ensure the job is idempotent and only updates the realm when drift exists

### Phase 4: Validation

- [x] Render the keycloak Kustomize package cleanly
- [x] Apply or sync the reconciler resources onto the cluster
- [x] Run the reconciler once and confirm the Keycloak realm `smtpServer` block matches Vault
- [x] Prove the job can be rerun safely without generating unnecessary writes

### Phase 5: Documentation and cleanup

- [x] Update the ticket diary with the implementation steps, failures, and validation commands
- [x] Update the ticket changelog and index status after the implementation lands
- [x] Update any K3s-side operator docs that should point at the reconciler as the canonical SMTP sync path

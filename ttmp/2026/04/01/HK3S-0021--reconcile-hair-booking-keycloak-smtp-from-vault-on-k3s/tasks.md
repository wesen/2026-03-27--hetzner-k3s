# Tasks

## Completed

- [x] Create `HK3S-0021` ticket workspace
- [x] Add the diary document

## Implementation Queue

### Phase 1: Ticket and scope setup

- [x] Record the current SMTP sync boundary and target design in the ticket
- [x] Add a concrete execution task list for the reconciler work

### Phase 2: Vault and auth wiring

- [ ] Add a dedicated Kubernetes Vault policy for the SMTP reconciler
- [ ] Add a dedicated Kubernetes Vault role bound to the reconciler service account
- [ ] Add the reconciler service account and `VaultAuth` resources in the keycloak namespace
- [ ] Add a `VaultStaticSecret` that mirrors `kv/apps/hair-booking/prod/ses` into the keycloak namespace

### Phase 3: Reconciler runtime

- [ ] Add the reconciler script ConfigMap
- [ ] Add the CronJob or Job manifest that runs the reconciliation
- [ ] Ensure the job reads admin creds and SMTP material from namespace-local Kubernetes secrets only
- [ ] Ensure the job is idempotent and only updates the realm when drift exists

### Phase 4: Validation

- [ ] Render the keycloak Kustomize package cleanly
- [ ] Apply or sync the reconciler resources onto the cluster
- [ ] Run the reconciler once and confirm the Keycloak realm `smtpServer` block matches Vault
- [ ] Prove the job can be rerun safely without generating unnecessary writes

### Phase 5: Documentation and cleanup

- [ ] Update the ticket diary with the implementation steps, failures, and validation commands
- [ ] Update the ticket changelog and index status after the implementation lands
- [ ] Update any K3s-side operator docs that should point at the reconciler as the canonical SMTP sync path

# Tasks

## Phase 1: Ticket and analysis

- [x] Create the HK3S-0021 workspace
- [x] Inspect the current `smailnail` runtime, deployment docs, and Keycloak configuration
- [x] Compare `smailnail` against an existing source-repo release path such as `hair-booking`
- [x] Compare `smailnail` against an existing K3s migration package such as `draft-review`
- [x] Write the detailed intern-facing migration design and implementation guide
- [x] Record the investigation diary
- [x] Validate the ticket bundle with `docmgr doctor`
- [x] Upload the final ticket bundle to reMarkable

## Phase 2: Source repo release automation

- [ ] Add `.github/workflows/publish-image.yaml` to the `smailnail` source repo
- [ ] Add `deploy/gitops-targets.json` to the `smailnail` source repo
- [ ] Add `scripts/open_gitops_pr.py` or a repo-local equivalent to the `smailnail` source repo
- [ ] Decide whether the published GHCR image will be public or private
- [ ] If private, confirm the cluster will use the existing Vault-backed GHCR pull-secret pattern
- [ ] Update the `smailnail` README to document the new GitHub Actions -> GHCR -> GitOps PR path

## Phase 3: Keycloak and platform identity

- [ ] Add or update the parallel K3s Keycloak environment for `smailnail` under the central Terraform repo
- [ ] Set browser-client redirect URIs and origins for the K3s app hostname
- [ ] Set MCP redirect URIs and audience/scope policy for the K3s app hostname
- [ ] Decide whether the existing hosted Terraform browser client is stale and should be corrected as part of this migration
- [ ] Keep the external Keycloak control plane as rollback until the K3s path is validated

## Phase 4: Vault and runtime secret shape

- [ ] Define the Vault path for the `smailnail` runtime secret
- [ ] Store app DB credentials in Vault
- [ ] Store the `smailnaild` encryption key in Vault
- [ ] Store OIDC client secrets in Vault
- [ ] If needed, store GHCR image-pull credentials in Vault
- [ ] Add or update Vault policies and Kubernetes auth roles for the `smailnail` service account

## Phase 5: GitOps package in this repo

- [ ] Add `gitops/kustomize/smailnail/namespace.yaml`
- [ ] Add `gitops/kustomize/smailnail/serviceaccount.yaml`
- [ ] Add `gitops/kustomize/smailnail/vault-connection.yaml`
- [ ] Add `gitops/kustomize/smailnail/vault-auth.yaml`
- [ ] Add `gitops/kustomize/smailnail/runtime-secret.yaml`
- [ ] Add `gitops/kustomize/smailnail/deployment.yaml`
- [ ] Add `gitops/kustomize/smailnail/service.yaml`
- [ ] Add `gitops/kustomize/smailnail/ingress.yaml`
- [ ] Add `gitops/kustomize/smailnail/kustomization.yaml`
- [ ] Add `gitops/applications/smailnail.yaml`

## Phase 6: Database decision and bootstrap

- [ ] Use shared PostgreSQL rather than SQLite for the K3s deployment
- [ ] Add a Vault-backed PostgreSQL bootstrap job if a new `smailnail` database and role are needed
- [ ] Verify that the application can run with DSN-based configuration
- [ ] Confirm that no PVC is required for the primary `smailnaild` app path once PostgreSQL is used

## Phase 7: Validation and cutover

- [ ] Verify the app reaches `Healthy` in Argo CD
- [ ] Verify `GET /readyz`
- [ ] Verify browser OIDC login against the K3s Keycloak hostname
- [ ] Verify `GET /api/me`
- [ ] Create an IMAP account through the hosted UI or API
- [ ] Verify rule creation and rule dry-run
- [ ] Verify bearer-authenticated MCP access using the stored `accountId` path
- [ ] Bootstrap the Argo CD `Application` object once with `kubectl apply`
- [ ] Decide whether and when to cut over from the existing hosted endpoint

## Phase 8: Optional Dovecot fixture migration

- [ ] Decide whether the hosted Dovecot fixture must move in the same project or in a follow-up ticket
- [ ] If yes, design the raw TCP exposure strategy on K3s explicitly
- [ ] If no, document that the app migration is complete even while the test fixture stays external

---
Title: "Provision Runtime Secrets and Identity for a New K3s App"
Slug: "app-runtime-secrets-and-identity-provisioning-playbook"
Short: "Operator playbook for the cross-repo Keycloak, Vault, VSO, and bootstrap steps that must exist before a new K3s app can roll."
Topics:
- vault
- keycloak
- kubernetes
- argocd
- gitops
- deployment
- ci-cd
Commands:
- terraform
- vault
- kubectl
- bash
Flags: []
IsTopLevel: true
IsTemplate: false
ShowPerDefault: true
SectionType: Tutorial
---

## What This Page Covers

This is the missing bridge playbook for a new K3s application that depends on:

- the reusable `infra-tooling` GHCR and GitOps PR workflow
- Keycloak-managed browser or MCP login
- Vault-backed runtime secrets
- Vault Secrets Operator rendering Kubernetes `Secret` objects
- an optional PostgreSQL bootstrap `Job`

The deployment chain is split across multiple repositories on purpose:

- source repo:
  - CI, tests, Dockerfile, `deploy/gitops-targets.json`
- `infra-tooling`:
  - reusable workflow and GitOps PR action
- `terraform`:
  - Keycloak realms and clients
- this K3s repo:
  - Argo `Application`, Kustomize package, Vault auth topology, and operator scripts

If you only read one app repo workflow and assume the rollout is complete, you
will miss the prerequisites that make the cluster able to authenticate, pull,
and start the app.

## Use This Playbook When

Use this page when all of the following are true:

- the source repo already publishes immutable GHCR tags through the shared
  `infra-tooling` workflow
- the GitOps repo already has a package under `gitops/kustomize/<app>/`
- the remaining question is: "what do I need to provision before this app can
  actually sync and start?"

For the source-repo and GitOps packaging side, start with:

- [source-app-deployment-infrastructure-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/source-app-deployment-infrastructure-playbook.md)
- [Source Repo To GitOps PR Flow](/home/manuel/code/wesen/corporate-headquarters/infra-tooling/docs/platform/source-repo-to-gitops-pr.md)

For the Keycloak Terraform side, use:

- [shared-keycloak-platform-playbook.md](/home/manuel/code/wesen/terraform/docs/shared-keycloak-platform-playbook.md)

## The System Boundary

The rollout is only ready when all of these layers line up:

```text
source repo
  -> publish immutable ghcr image
  -> open GitOps PR

terraform repo
  -> Keycloak realm/client state matches the K3s hostname

vault
  -> runtime secret values exist
  -> image pull credentials exist
  -> kubernetes auth roles and policies exist

gitops repo
  -> VaultAuth, VaultStaticSecret, Deployment, Service, Ingress, Job

cluster
  -> VSO can read from Vault
  -> bootstrap job can create DB objects
  -> workload can pull the image
  -> workload can start and log in
```

## Checklist Before First Sync

Do not merge the first app GitOps PR and expect a healthy rollout until this
checklist is complete.

### 1. Keycloak K3s environment exists

The app needs a Keycloak env that points at the K3s hostname, not the older
Coolify or hosted hostname.

Preferred shape:

- `terraform/keycloak/apps/<app>/envs/k3s-parallel/`

That env should manage:

- the K3s-facing browser client
- any K3s-facing MCP client if the app exposes an MCP endpoint
- redirect URIs and post-logout URIs for the K3s hostname

### 2. Vault runtime secret path exists

If the Kustomize package contains a `VaultStaticSecret` like:

```yaml
path: apps/<app>/prod/runtime
```

then the operator must actually write that path in Vault before the app sync is
useful.

Typical runtime keys:

- database name
- database username
- database password
- DSN or service host/port
- OIDC client secret
- session secret
- encryption keys or app-private bootstrap values

### 3. Vault image-pull secret path exists

If the GHCR package is private, the app also needs:

```yaml
path: apps/<app>/prod/image-pull
```

Typical keys:

- `server`
- `username`
- `password`
- `auth`

### 4. Vault Kubernetes auth policy and role exist

The `VaultAuth` Kubernetes resources in Git are not enough by themselves.
Vault must also know the matching auth role and policy.

Typical files in this repo:

- `vault/policies/kubernetes/<app>.hcl`
- `vault/policies/kubernetes/<app>-db-bootstrap.hcl`
- `vault/roles/kubernetes/<app>.json`
- `vault/roles/kubernetes/<app>-db-bootstrap.json`

### 5. PostgreSQL bootstrap contract is valid

If the app uses the shared PostgreSQL bootstrap-job pattern, confirm:

- `infra/postgres/cluster` exists in Vault
- the app runtime secret contains the exact keys referenced by the bootstrap
  `Job`
- the job is idempotent and uses least-privilege runtime credentials for the
  app itself

Reference:

- [vault-backed-postgres-bootstrap-job-pattern.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/vault-backed-postgres-bootstrap-job-pattern.md)

### 6. Argo `Application` bootstrap has happened once

For a brand-new app:

```bash
kubectl apply -f gitops/applications/<app>.yaml
kubectl -n argocd annotate application <app> argocd.argoproj.io/refresh=hard --overwrite
```

## Recommended Operator Sequence

Use this exact order.

### Phase 1: Identity

1. Create or update `terraform/keycloak/apps/<app>/envs/k3s-parallel/`.
2. Run:

```bash
cd /home/manuel/code/wesen/terraform/keycloak/apps/<app>/envs/k3s-parallel
terraform init
terraform validate
terraform plan
terraform apply
```

3. Record the client IDs, redirect URIs, and any generated secrets.

### Phase 2: Vault values

1. Seed the runtime secret path.
2. Seed the image-pull secret path if the package is private.
3. Reuse existing cluster-level secret paths such as:
   - `infra/postgres/cluster`

This repository already contains concrete bootstrap examples for other apps:

- [bootstrap-coinvault-image-pull-secret.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-coinvault-image-pull-secret.sh)
- [bootstrap-pretext-trace-image-pull-secret.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-pretext-trace-image-pull-secret.sh)
- [bootstrap-cluster-postgres-secrets.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-cluster-postgres-secrets.sh)

If a new app has a nontrivial runtime contract, create an app-specific bootstrap
script in `scripts/` so the operator does not have to reconstruct the exact
`vault kv put` payload manually every time.

### Phase 3: Vault Kubernetes auth

1. Add the app policy and role files under:
   - `vault/policies/kubernetes/`
   - `vault/roles/kubernetes/`
2. Run:

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
./scripts/bootstrap-vault-kubernetes-auth.sh
```

3. If there is a new policy boundary, validate it with:

```bash
./scripts/validate-vault-kubernetes-auth.sh
```

### Phase 4: GitOps rollout

1. Merge the image-bump PR in the GitOps repo.
2. Apply the `Application` resource once if this is the app’s first rollout.
3. Watch Argo and the namespace:

```bash
kubectl -n argocd get application <app> -w
kubectl -n <app> get pods -w
kubectl -n <app> get jobs
kubectl -n <app> get secret
```

### Phase 5: Runtime validation

Validate the real surfaces:

- pod readiness and liveness
- ingress hostname
- browser login
- logout if the app uses browser logout callbacks
- MCP auth path if the app exposes MCP
- successful completion of any DB bootstrap `Job`

## Minimal File Contract Per Repo

### Source repo

- `Dockerfile`
- `.github/workflows/publish-image.yaml`
- `deploy/gitops-targets.json`

### `infra-tooling`

- reusable publish workflow
- reusable `open-gitops-pr` action

### Terraform repo

- `keycloak/apps/<app>/envs/k3s-parallel/`

### K3s repo

- `gitops/kustomize/<app>/`
- `gitops/applications/<app>.yaml`
- `vault/policies/kubernetes/<app>*.hcl`
- `vault/roles/kubernetes/<app>*.json`
- optional `scripts/bootstrap-<app>-*.sh`

## Common Failure Modes

### CI publishes and opens the PR, but the Pod hits `ImagePullBackOff`

Cause:

- image-pull secret path missing or wrong
- service account not referencing the rendered pull secret

### VSO resources exist, but no Kubernetes `Secret` appears

Cause:

- Vault auth role or policy missing
- Vault path exists in Git but not in Vault

### Browser login redirects to the wrong hostname

Cause:

- Keycloak env still points at the older hosted/Coolify hostname
- K3s redirect and logout URIs were not applied

### DB bootstrap job fails immediately

Cause:

- runtime secret missing required database keys
- cluster admin secret path missing
- role/policy does not allow the bootstrap service account to read both paths

## Recommended Future Rule

For every new K3s app that needs private images or identity, the operator
handoff should include two things before rollout:

1. a `k3s-parallel` Keycloak env
2. at least one repo-owned bootstrap script for the app’s Vault secrets

That keeps the last-mile provisioning reproducible instead of relying on memory.

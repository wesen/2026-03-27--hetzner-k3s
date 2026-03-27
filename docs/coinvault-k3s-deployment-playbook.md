---
Title: "Deploy CoinVault on This K3s Cluster"
Slug: "coinvault-k3s-deployment-playbook"
Short: "Understand and execute the full CoinVault deployment on the Hetzner K3s cluster, including Vault, VSO, Argo CD, MySQL, OIDC, image import, and validation."
Topics:
- coinvault
- argocd
- gitops
- vault
- kubernetes
- mysql
- oidc
- deployment
Commands:
- kubectl
- vault
- docker
- ssh
- op
- git
Flags: []
IsTopLevel: true
IsTemplate: false
ShowPerDefault: true
SectionType: Tutorial
---

## What This Page Covers

This page is the cluster-operator playbook for deploying CoinVault onto the Hetzner single-node K3s environment managed by this repository. It is intentionally written for a new intern. That means it does not start with commands. It starts with the system model, the ownership boundaries, and the reason each moving part exists.

If you skip the conceptual model, the deployment looks like a random pile of YAML, Vault secrets, and one-off shell scripts. If you understand the model first, the repo becomes much easier to reason about:

- Argo CD owns the Kubernetes objects
- Vault owns secret values
- Vault Secrets Operator turns Vault values into Kubernetes `Secret` objects
- MySQL provides the application’s shared relational data
- CoinVault itself is just a web application plus two SQLite files for local timeline and turns state

This guide assumes the cluster already exists and Argo CD, Vault, Vault Kubernetes auth, Vault Secrets Operator, and the shared MySQL service are already running.

## System Overview

CoinVault on this cluster is not a single manifest. It is a chain of responsibilities:

```text
Git (this repo)
  -> Argo CD Application
    -> Kustomize package
      -> Namespace / ServiceAccount / PVC / Deployment / Service / Ingress
      -> VaultConnection / VaultAuth / VaultStaticSecret
        -> Vault Kubernetes auth
          -> Vault KV secrets
            -> Kubernetes Secret objects
              -> CoinVault container environment + mounted profile files
                -> CoinVault runtime
                  -> MySQL + Keycloak + Traefik ingress
```

If any layer in that chain is missing, the app will not behave correctly. For example:

- if the image is missing, the pod never starts
- if Vault auth is misconfigured, VSO never materializes the secrets
- if the MySQL host still points at Coolify, CoinVault boots but fails data access
- if Keycloak redirect URIs do not include the K3s hostname, login redirects fail

## Why This Deployment Looks Different from the Old Hosted Setup

The older hosted CoinVault deployment used an off-cluster bootstrap step. The container started in “Vault bootstrap mode,” logged into Vault via AppRole, fetched its own runtime material, and wrote local files before starting the web server.

On K3s, that pattern is no longer the right default. Once the application is inside Kubernetes, the better pattern is:

- Vault Kubernetes auth for workload identity
- Vault Secrets Operator for secret synchronization
- plain Kubernetes `Secret` consumption by the pod

That means the CoinVault deployment here uses:

- `COINVAULT_BOOTSTRAP_MODE=disabled`
- a VSO-synced `Secret` named `coinvault-runtime`
- a VSO-synced `Secret` named `coinvault-pinocchio`

The app still uses the same runtime concepts, but the delivery mechanism changed from “container logs into Vault itself” to “cluster controller projects Vault values into Kubernetes-native inputs.”

## Repo Layout

These are the files you should read first when operating this deployment:

- [`gitops/applications/coinvault.yaml`](../gitops/applications/coinvault.yaml): the Argo CD `Application`
- [`gitops/kustomize/coinvault/kustomization.yaml`](../gitops/kustomize/coinvault/kustomization.yaml): the Kustomize entry point
- [`gitops/kustomize/coinvault/deployment.yaml`](../gitops/kustomize/coinvault/deployment.yaml): the CoinVault pod spec
- [`gitops/kustomize/coinvault/vault-auth.yaml`](../gitops/kustomize/coinvault/vault-auth.yaml): how VSO authenticates to Vault
- [`gitops/kustomize/coinvault/vault-static-secret-runtime.yaml`](../gitops/kustomize/coinvault/vault-static-secret-runtime.yaml): runtime secret sync
- [`gitops/kustomize/coinvault/vault-static-secret-pinocchio.yaml`](../gitops/kustomize/coinvault/vault-static-secret-pinocchio.yaml): Pinocchio config/profile sync
- [`scripts/seed-coinvault-k3s-vault-secrets.sh`](../scripts/seed-coinvault-k3s-vault-secrets.sh): copies runtime material into the K3s Vault
- [`scripts/build-and-import-coinvault-image.sh`](../scripts/build-and-import-coinvault-image.sh): builds the image from the app repo and imports it into the K3s node
- [`scripts/validate-coinvault-k3s.sh`](../scripts/validate-coinvault-k3s.sh): smoke validation after rollout
- [`vault/policies/kubernetes/coinvault-prod.hcl`](../vault/policies/kubernetes/coinvault-prod.hcl): Vault least-privilege policy
- [`vault/roles/kubernetes/coinvault-prod.json`](../vault/roles/kubernetes/coinvault-prod.json): Vault Kubernetes auth role

You should also keep the app-repo playbook nearby:

- [`docs/deployments/coinvault-argocd-deployment-playbook.md`](/home/manuel/code/gec/2026-03-16--gec-rag/docs/deployments/coinvault-argocd-deployment-playbook.md)

## The Runtime Contract

CoinVault needs four broad classes of input:

1. Application image
2. Secret material
3. Data dependencies
4. Public routing/auth settings

### 1. Application Image

The current deployment uses a locally imported image:

- image name: `coinvault:hk3s-0007`
- pull policy: `Never`

That is unusual in production, but correct for the current single-node bootstrap model. The important idea is that K3s containerd must already have the image locally. If the image is not present on the node, Kubernetes cannot pull it from anywhere.

### 2. Secret Material

CoinVault consumes two Kubernetes secrets:

- `coinvault-runtime`
- `coinvault-pinocchio`

They are not committed in Git. VSO creates them from Vault paths:

- `kv/apps/coinvault/prod/runtime`
- `kv/apps/coinvault/prod/pinocchio`

Expected runtime keys:

- `session_secret`
- `oidc_client_secret`
- `gec_mysql_host`
- `gec_mysql_port`
- `gec_mysql_database`
- `gec_mysql_ro_user`
- `gec_mysql_ro_password`

Expected Pinocchio keys:

- `profiles_yaml`
- `config_yaml`

### 3. Data Dependencies

CoinVault uses two kinds of persistence:

- MySQL for application/business data
- local SQLite files for timeline and turns state

Current paths:

- MySQL host: `mysql.mysql.svc.cluster.local`
- MySQL port: `3306`
- MySQL database: `gec`
- timeline DB: `/data/coinvault-timeline.db`
- turns DB: `/data/coinvault-turns.db`

This means CoinVault is not fully stateless. The pod relies on the PVC in [`persistentvolumeclaim.yaml`](../gitops/kustomize/coinvault/persistentvolumeclaim.yaml) for the SQLite files.

### 4. Public Routing and Auth

Public routes are:

- app URL: `https://coinvault.yolo.scapegoat.dev`
- OIDC issuer: `https://auth.scapegoat.dev/realms/coinvault`

Ingress is handled by Traefik via:

- [`gitops/kustomize/coinvault/ingress.yaml`](../gitops/kustomize/coinvault/ingress.yaml)

OIDC client registration is not in this repo. It lives in the shared Terraform repo. That is an important ownership boundary:

- app URL and K8s ingress are owned here
- Keycloak client redirect/origin policy lives in `/home/manuel/code/wesen/terraform`

## Deployment Sequence

This is the actual operator order. Read the explanation under each step before running commands.

### Step 1: Verify Platform Preconditions

Before touching CoinVault, make sure the platform controllers it depends on are healthy.

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml

kubectl get nodes
kubectl -n argocd get applications
kubectl -n vault get pods
kubectl -n vault-secrets-operator-system get pods
kubectl -n mysql get pods
```

You want:

- node `Ready`
- Argo CD up
- Vault `Running`
- VSO controller `Running`
- MySQL `Running`

Why this matters: if VSO or Vault is unhealthy, debugging CoinVault first is wasted effort.

### Step 2: Verify the Vault Role and Policy Boundary

CoinVault should not read arbitrary Vault paths. It should read only its own subtree through Kubernetes auth.

Files that define this:

- [`vault/policies/kubernetes/coinvault-prod.hcl`](../vault/policies/kubernetes/coinvault-prod.hcl)
- [`vault/roles/kubernetes/coinvault-prod.json`](../vault/roles/kubernetes/coinvault-prod.json)

Mental model:

```text
Kubernetes service account: coinvault / namespace coinvault
  -> authenticates to Vault Kubernetes auth
  -> receives token with policy coinvault-prod
  -> can read kv/apps/coinvault/prod/*
  -> cannot read other app paths
```

If you need to re-bootstrap that layer, the broader platform instructions are in:

- [`docs/hetzner-k3s-server-setup.md`](./hetzner-k3s-server-setup.md)
- [`docs/argocd-app-setup.md`](./argocd-app-setup.md)

### Step 3: Seed the CoinVault Secrets into the K3s Vault

The K3s Vault is the secret source for VSO. If it does not contain the application payloads, the rest of the deployment cannot hydrate.

Script:

- [`scripts/seed-coinvault-k3s-vault-secrets.sh`](../scripts/seed-coinvault-k3s-vault-secrets.sh)

What it does:

- reads runtime and Pinocchio payloads from a source Vault
- writes them into the K3s Vault
- allows MySQL endpoint overrides so the K3s deployment points at the cluster-local MySQL service

Pseudocode:

```text
read old runtime secret
read old pinocchio secret
override mysql host/user/password for K3s if provided
write runtime secret to kv/apps/coinvault/prod/runtime in K3s Vault
write pinocchio secret to kv/apps/coinvault/prod/pinocchio in K3s Vault
```

Example shape:

```bash
export SOURCE_VAULT_ADDR=...
export SOURCE_VAULT_TOKEN=...
export DEST_VAULT_ADDR=https://vault.yolo.scapegoat.dev
export DEST_VAULT_TOKEN=...
export COINVAULT_GEC_MYSQL_HOST=mysql.mysql.svc.cluster.local
export COINVAULT_GEC_MYSQL_PORT=3306
export COINVAULT_GEC_MYSQL_DATABASE=gec
export COINVAULT_GEC_MYSQL_RO_USER=coinvault_ro
export COINVAULT_GEC_MYSQL_RO_PASSWORD=...

./scripts/seed-coinvault-k3s-vault-secrets.sh
```

Afterward, verify without printing secrets:

```bash
export VAULT_ADDR=https://vault.yolo.scapegoat.dev
vault kv metadata get kv/apps/coinvault/prod/runtime
vault kv metadata get kv/apps/coinvault/prod/pinocchio
```

### Step 4: Build and Import the Image

The cluster does not pull the CoinVault image from a registry. Instead, this repo provides a helper that builds from the app repo and imports the image directly into the K3s node’s containerd store.

Script:

- [`scripts/build-and-import-coinvault-image.sh`](../scripts/build-and-import-coinvault-image.sh)

Why this script exists:

- the app repo still contains workstation-local `go mod replace` directives during development
- building directly from the raw repo can fail in Docker
- the script creates a temporary build context, removes those local replace directives, runs `go mod tidy`, builds the image, and then streams it to the node

Pseudocode:

```text
copy app repo into temp build directory
remove local go.mod replaces
run go mod tidy
docker build coinvault:hk3s-0007
docker save | ssh root@node 'k3s ctr images import -'
```

Run:

```bash
export K3S_NODE_HOST=91.98.46.169
./scripts/build-and-import-coinvault-image.sh
```

Then verify:

```bash
ssh root@91.98.46.169 "k3s ctr images ls | grep coinvault"
```

### Step 5: Validate the Kustomize Package Before Argo Uses It

Even though Argo is the long-term deployer, you should render locally first.

```bash
kubectl kustomize gitops/kustomize/coinvault
```

You are checking for:

- valid YAML output
- expected namespace `coinvault`
- expected secret names
- expected service account
- expected ingress host

Key files in the package:

- [`namespace.yaml`](../gitops/kustomize/coinvault/namespace.yaml)
- [`serviceaccount.yaml`](../gitops/kustomize/coinvault/serviceaccount.yaml)
- [`persistentvolumeclaim.yaml`](../gitops/kustomize/coinvault/persistentvolumeclaim.yaml)
- [`deployment.yaml`](../gitops/kustomize/coinvault/deployment.yaml)
- [`service.yaml`](../gitops/kustomize/coinvault/service.yaml)
- [`ingress.yaml`](../gitops/kustomize/coinvault/ingress.yaml)

### Step 6: Apply or Refresh the Argo CD Application

Argo’s durable entry point is the `Application` object:

- [`gitops/applications/coinvault.yaml`](../gitops/applications/coinvault.yaml)

Apply or refresh it:

```bash
kubectl apply -f gitops/applications/coinvault.yaml
kubectl -n argocd annotate application coinvault argocd.argoproj.io/refresh=hard --overwrite
```

Then watch status:

```bash
kubectl -n argocd get application coinvault \
  -o jsonpath='{.status.sync.status}{"\n"}{.status.health.status}{"\n"}{.spec.source.path}{"\n"}'
```

Expected:

```text
Synced
Healthy
gitops/kustomize/coinvault
```

### Step 7: Understand the PVC and Sync-Wave Trap

This deployment already hit one non-obvious Argo failure mode, so it is worth documenting explicitly for interns.

The PVC uses the `local-path` storage class. That class can wait for a consumer pod before binding. If Argo puts the PVC in an earlier sync wave than the Deployment, the following deadlock can occur:

```text
Argo applies PVC
  -> PVC waits for first consumer
Argo waits for PVC to be healthy
  -> Deployment is not applied yet
No pod exists to consume PVC
  -> PVC never binds
```

That is why the current repo places the PVC and Deployment so they can converge together instead of blocking one another.

If you see a pending PVC and an absent pod during sync, check sync-wave annotations first.

### Step 8: Verify VSO Secret Materialization

Argo can say `Synced` while the app still fails if the secret sync layer is broken.

Inspect the secret-producing resources:

```bash
kubectl -n coinvault get vaultauth,vaultstaticsecret
kubectl -n coinvault get secret coinvault-runtime coinvault-pinocchio
```

Check the synced keys:

```bash
kubectl -n coinvault get secret coinvault-runtime -o json | jq -r '.data | keys[]'
kubectl -n coinvault get secret coinvault-pinocchio -o json | jq -r '.data | keys[]'
```

You should see:

- runtime keys for OIDC session and MySQL access
- `profiles_yaml`
- `config_yaml`

### Step 9: Inspect the Running Pod

Once the Deployment is healthy, check the pod’s effective configuration rather than assuming the manifest is enough.

```bash
kubectl -n coinvault get pods
kubectl -n coinvault exec -it deploy/coinvault -- sh
```

Inside the pod, useful checks are:

```sh
env | sort | grep '^COINVAULT_'
ls -la /run/secrets/pinocchio
sed -n '1,120p' /run/secrets/pinocchio/profiles.yaml
sed -n '1,120p' /run/secrets/pinocchio/config.yaml
```

Important runtime facts:

- the deployment sets `COINVAULT_PROFILE_REGISTRIES=/run/secrets/pinocchio/profiles.yaml`
- the app is not supposed to fall back to `./profile-registry.yaml`
- the app is not using bootstrap mode on K3s

### Step 10: Run the Validation Script

Script:

- [`scripts/validate-coinvault-k3s.sh`](../scripts/validate-coinvault-k3s.sh)

Run:

```bash
export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml
./scripts/validate-coinvault-k3s.sh
```

What it proves:

- the Argo app is `Synced Healthy`
- the Deployment rolled out
- the destination Kubernetes secrets exist
- `/healthz` responds
- `/auth/login` redirects to OIDC

### Step 11: Validate the Database

CoinVault can be healthy at the HTTP layer and still fail functional pages if MySQL is empty or mispointed.

Shared MySQL contract:

- service: `mysql.mysql.svc.cluster.local`
- schema: `gec`
- read-only app user: `coinvault_ro`

The live migration imported the local `gec_dev` dataset into the cluster `gec` schema. The important lesson is that schema existence matters just as much as host reachability.

Typical check:

```bash
kubectl -n mysql exec statefulset/mysql -- \
  mysql -uroot -p"$MYSQL_ROOT_PASSWORD" gec -e 'SHOW TABLES;'
```

If the app reports missing tables such as `gec.products`, the infrastructure is only half migrated.

### Step 12: Validate Browser Login and Real Behavior

The final validation is a real browser session:

1. Open `https://coinvault.yolo.scapegoat.dev`
2. Start login via `/auth/login`
3. Complete Keycloak login
4. Confirm `GET /api/me` shows an authenticated user
5. Open the quick-stats UI or inventory views
6. Submit a short chat request

You are looking for proof that:

- TLS works
- login redirects work
- session secret is valid
- MySQL reads work
- the Pinocchio profile registry actually loads

## Common Failure Modes

### Failure: OpenAI 401 “You didn't provide an API key”

Symptom:

```text
401 Unauthorized
You didn't provide an API key
```

Likely causes:

- mounted `profiles.yaml` exists but the app is not actually using it
- `config.yaml` or provider config is inconsistent with the active profile
- the live profile registry path fell back to the repo default path

Historically, this ticket hit a deeper parsing bug:

- the setting came from both env and CLI flag
- Glazed merged that into a list-like field shape
- CoinVault’s resolver treated it as a scalar string
- the app silently fell back to `./profile-registry.yaml`

Relevant app files:

- [`profile_settings.go`](/home/manuel/code/gec/2026-03-16--gec-rag/cmd/coinvault/cmds/profile_settings.go)
- [`entrypoint.sh`](/home/manuel/code/gec/2026-03-16--gec-rag/docker/entrypoint.sh)

### Failure: startup crashes parsing `COINVAULT_PORT=tcp://...`

Cause:

- Kubernetes service links auto-injected `COINVAULT_PORT`
- CoinVault’s Glazed config parser interpreted it as application config

Fix:

- set `enableServiceLinks: false`
- use explicit `COINVAULT_SERVE_PORT`

### Failure: Argo stuck before pod creation

Cause:

- PVC in earlier sync wave than Deployment
- `WaitForFirstConsumer` deadlock

Fix:

- align the wave ordering so the pod can schedule and bind the PVC

### Failure: Login redirect loops or Keycloak callback rejection

Cause:

- Keycloak client does not trust the K3s hostname

Boundary:

- fix lives in `/home/manuel/code/wesen/terraform/keycloak/apps/coinvault/envs/hosted/main.tf`
- not in this repo

### Failure: VSO secrets never appear

Cause candidates:

- Vault unreachable
- Vault Kubernetes auth misconfigured
- wrong service account / namespace binding
- wrong Vault path or policy

Check:

```bash
kubectl -n coinvault describe vaultauth coinvault
kubectl -n coinvault describe vaultstaticsecret coinvault-runtime
kubectl -n coinvault describe vaultstaticsecret coinvault-pinocchio
```

## Recovery and Rollback Model

This K3s deployment is currently a parallel environment, not an irreversible cutover.

That means rollback is conceptually simple:

- keep the old hosted deployment available
- stop sending traffic/users to the K3s hostname if a critical problem appears
- fix the K3s environment without destroying the old one

Important nuance:

- rollback for the web app is easy
- rollback for mutable data is harder once users start writing to the new environment

That is why a real cutover plan must include data ownership and write-path timing, not just DNS changes.

## Review Checklist for an Intern

When reviewing a future CoinVault deploy, walk in this order:

1. Read [`gitops/applications/coinvault.yaml`](../gitops/applications/coinvault.yaml)
2. Read [`gitops/kustomize/coinvault/kustomization.yaml`](../gitops/kustomize/coinvault/kustomization.yaml)
3. Inspect secret wiring in [`deployment.yaml`](../gitops/kustomize/coinvault/deployment.yaml)
4. Inspect Vault sync resources
5. Verify the image exists on the node
6. Verify Argo sync/health
7. Verify VSO-produced secrets
8. Verify pod health and mounted files
9. Verify login and business functionality

## API and Resource References

These are the core APIs involved in this deployment:

- Argo CD `Application`
  - `apiVersion: argoproj.io/v1alpha1`
- Kubernetes `Deployment`, `Service`, `Ingress`, `PersistentVolumeClaim`, `ServiceAccount`
  - `apiVersion: apps/v1`, `v1`, `networking.k8s.io/v1`
- Vault Secrets Operator `VaultConnection`, `VaultAuth`, `VaultStaticSecret`
  - `apiVersion: secrets.hashicorp.com/v1beta1`

Practical `kubectl api-resources` checks:

```bash
kubectl api-resources | grep -E 'applications.argoproj.io|vaultauth|vaultstaticsecret|vaultconnection'
```

## Final Mental Model

If you remember only one thing from this page, remember this:

CoinVault on K3s is not “deploy this image.” It is “make five controllers and contracts agree on the same runtime story.”

That story is:

- Argo owns the manifests
- Vault owns the secret values
- VSO bridges Vault into Kubernetes
- MySQL owns shared application data
- CoinVault consumes those inputs and serves the user-facing app

Once you understand that contract, the deployment stops looking magical and starts looking debuggable.

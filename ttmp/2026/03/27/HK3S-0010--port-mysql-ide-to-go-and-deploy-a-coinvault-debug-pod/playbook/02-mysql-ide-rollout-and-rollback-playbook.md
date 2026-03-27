---
Title: MySQL IDE rollout and rollback playbook
Ticket: HK3S-0010
Status: active
Topics:
    - coinvault
    - mysql
    - oidc
    - k3s
    - gitops
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../gitops/kustomize/coinvault/mysql-ide-deployment.yaml
      Note: Main workload manifest
    - Path: ../../../../../../../gitops/kustomize/coinvault/mysql-ide-service.yaml
      Note: Stable service contract
    - Path: ../../../../../../../gitops/kustomize/coinvault/mysql-ide-ingress.yaml
      Note: Public ingress and TLS host
    - Path: ../../../../../../../scripts/build-and-import-mysql-ide-image.sh
      Note: Single-node image import path
    - Path: ../../../../../../../../terraform/keycloak/apps/coinvault/envs/hosted/main.tf
      Note: Keycloak redirect URI coverage for the debug host
    - Path: ../../../../../../../../2026-03-27--mysql-ide/README.md
      Note: App-side runtime and local development documentation
ExternalSources: []
Summary: Detailed operator playbook for rebuilding, rolling out, validating, and rolling back the CoinVault MySQL IDE deployment.
LastUpdated: 2026-03-27T17:41:00-04:00
WhatFor: Use this when changing the MySQL IDE service, importing a new image, or recovering the deployment after a bad rollout.
WhenToUse: Read this before operating the CoinVault SQL debug service on the K3s cluster.
---

# MySQL IDE rollout and rollback playbook

## Purpose

This playbook explains how to operate the MySQL IDE debug tool that lives next to CoinVault on the K3s cluster. The intended reader is a new intern or operator who needs to understand both the moving parts and the exact command path for a safe rollout.

The deployment is intentionally narrow:

- one Go service
- one Deployment, Service, and Ingress in namespace `coinvault`
- one fixed MySQL target contract taken from `coinvault-runtime`
- one OIDC login path through the existing `coinvault-web` Keycloak client

That narrow shape is what makes the tool safe enough to expose as an operator-only debugging surface.

## What the system is

At a high level, the runtime graph looks like this:

```text
operator browser
  -> https://coinvault-sql.yolo.scapegoat.dev
  -> Traefik ingress
  -> mysql-ide Deployment
  -> Keycloak realm coinvault for browser auth
  -> mysql.mysql.svc.cluster.local:3306 using read-only CoinVault DB credentials
```

The important architectural rule is that the browser does not choose which database to connect to. The pod gets its DB contract from the cluster secret, and the server uses that contract for every request.

## Files that matter

Cluster repo:

- [mysql-ide-deployment.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml)
- [mysql-ide-service.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-service.yaml)
- [mysql-ide-ingress.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-ingress.yaml)
- [kustomization.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/kustomization.yaml)
- [build-and-import-mysql-ide-image.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/build-and-import-mysql-ide-image.sh)

App repo:

- [main.go](/home/manuel/code/wesen/2026-03-27--mysql-ide/cmd/mysql-ide/main.go)
- [server.go](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/httpapi/server.go)
- [config.go](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/app/config.go)
- [index.html](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/httpapi/static/index.html)
- [schema.go](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/sqlguard/schema.go)
- [README.md](/home/manuel/code/wesen/2026-03-27--mysql-ide/README.md)

Identity repo:

- [main.tf](/home/manuel/code/wesen/terraform/keycloak/apps/coinvault/envs/hosted/main.tf)

## Preconditions

Before rolling out a change, confirm these prerequisites:

- you have cluster access through:
  - [kubeconfig-91.98.46.169.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/kubeconfig-91.98.46.169.yaml)
- the K3s node is reachable over SSH
- Docker is available locally
- the app repo change has been committed in:
  - `/home/manuel/code/wesen/2026-03-27--mysql-ide`
- the GitOps repo change has been committed in:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s`

If the change affects OIDC redirects, you also need the Terraform repo and the live Keycloak client secret.

## Standard rollout flow

### 1. Validate the app repo locally

```bash
cd /home/manuel/code/wesen/2026-03-27--mysql-ide
go test ./...
go build ./cmd/mysql-ide
docker build -t mysql-ide:hk3s-0010 .
```

If these fail, do not touch the cluster yet.

### 2. Build and import the image into the K3s node

The current cluster is single-node K3s and the manifest uses `imagePullPolicy: Never`, so the node must have the image in its local containerd.

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export K3S_NODE_HOST=91.98.46.169
./scripts/build-and-import-mysql-ide-image.sh
```

What that script does:

```text
docker build local image
  -> docker save
  -> ssh to node
  -> k3s ctr images import
```

### 3. Apply or let Argo reconcile the GitOps manifests

For fast operator iteration, it is acceptable to apply the local working tree and then push the same manifests so Argo converges back onto Git.

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml
kubectl apply -k gitops/kustomize/coinvault
```

Then restart the deployment if only the image changed:

```bash
kubectl -n coinvault rollout restart deploy/mysql-ide
kubectl -n coinvault rollout status deploy/mysql-ide --timeout=120s
```

### 4. If needed, update Keycloak redirect coverage

Only do this when you add or change the public hostname.

Important: the Terraform repo root `.envrc` contains defaults for another realm. Override the CoinVault variables explicitly before planning or applying.

```bash
cd /home/manuel/code/wesen/terraform
source .envrc

export TF_VAR_realm_name=coinvault
export TF_VAR_realm_display_name=coinvault
export TF_VAR_public_app_url=https://coinvault.app.scapegoat.dev
export TF_VAR_web_client_secret="$(
  KUBECONFIG=/home/manuel/code/wesen/2026-03-27--hetzner-k3s/kubeconfig-91.98.46.169.yaml \
  kubectl -n coinvault get secret coinvault-runtime -o jsonpath='{.data.oidc_client_secret}' | base64 -d
)"

terraform -chdir=keycloak/apps/coinvault/envs/hosted plan -no-color
terraform -chdir=keycloak/apps/coinvault/envs/hosted apply -auto-approve -no-color
```

Why this override matters:

```text
wrong root .envrc defaults
  -> wrong realm/public URL
  -> Terraform plans destructive client replacement
  -> operator accidentally mutates unrelated identity config
```

## Validation flow

### 1. Confirm the Deployment is healthy

```bash
export KUBECONFIG=/home/manuel/code/wesen/2026-03-27--hetzner-k3s/kubeconfig-91.98.46.169.yaml
kubectl -n coinvault get deploy mysql-ide
kubectl -n coinvault get pods -l app.kubernetes.io/name=mysql-ide
kubectl -n coinvault logs deploy/mysql-ide --tail=200
```

### 2. Confirm the public endpoint and auth behavior

```bash
curl -ksS https://coinvault-sql.yolo.scapegoat.dev/healthz
curl -ksSI https://coinvault-sql.yolo.scapegoat.dev/
curl -ksS https://coinvault-sql.yolo.scapegoat.dev/api/me
```

Expected behavior:

- `/healthz` returns `ok: true`
- `/` redirects to `/auth/login` for anonymous users
- `/api/me` reports `authenticated: false` until login

### 3. Confirm authenticated browser behavior

In a real browser:

- log in through Keycloak
- verify the schema tree loads
- inspect `products`
- run a safe read query such as:

```sql
SELECT id, product_id, title
FROM products
ORDER BY id DESC
LIMIT 20;
```

- verify an unsafe query fails:

```sql
DELETE FROM products;
```

Expected unsafe-query result:

- server-side rejection
- no database mutation

### 4. Confirm Argo is converged after push

```bash
export KUBECONFIG=/home/manuel/code/wesen/2026-03-27--hetzner-k3s/kubeconfig-91.98.46.169.yaml
kubectl -n argocd get application coinvault -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'
```

Target state:

- `Synced Healthy`

## Rollback strategy

There are three rollback scopes. Choose the smallest one that solves the problem.

### Scope 1: restart the current pod

Use this when the image is present and the manifest is correct, but the pod is wedged.

```bash
kubectl -n coinvault rollout restart deploy/mysql-ide
kubectl -n coinvault rollout status deploy/mysql-ide --timeout=120s
```

### Scope 2: roll back the GitOps manifest

Use this when the current deployment shape is wrong.

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
git log -- gitops/kustomize/coinvault/mysql-ide-deployment.yaml
git revert <bad-commit>
git push
```

Then verify Argo reconciles back to `Synced Healthy`.

### Scope 3: remove the public debug surface entirely

Use this when the service itself is causing confusion or must be taken offline quickly.

Temporary emergency response:

```bash
kubectl -n coinvault delete ingress mysql-ide
kubectl -n coinvault delete service mysql-ide
kubectl -n coinvault delete deploy mysql-ide
```

Then follow up by reverting the corresponding Git commit, or Argo will recreate the objects.

## Known operational boundaries

- The app repo currently has no configured Git remote, so app-repo pushes are not yet part of the normal release story.
- The cluster uses local image import, not registry pulls.
- The tool reuses `coinvault-runtime`; it does not currently have a dedicated Vault secret subtree.
- The tool is read-only by policy, but it still exposes production data to authenticated operators. Treat it as an operator surface, not an end-user feature.

## Troubleshooting guide

### Symptom: anonymous users see 500 instead of redirect

Check:

- `MYSQL_IDE_AUTH_MODE`
- `MYSQL_IDE_AUTH_PUBLIC_URL`
- `MYSQL_IDE_OIDC_ISSUER_URL`
- `MYSQL_IDE_OIDC_CLIENT_ID`
- `MYSQL_IDE_OIDC_CLIENT_SECRET`

Primary file:

- [mysql-ide-deployment.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml)

### Symptom: schema tree fails to load

Check pod logs for metadata scan errors and review:

- [schema.go](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/sqlguard/schema.go)

This was the exact failure mode during the initial live smoke test because MySQL metadata columns needed explicit aliases for `sqlx`.

### Symptom: OIDC redirect fails

Check:

- public hostname in ingress
- redirect URL coverage in:
  - [main.tf](/home/manuel/code/wesen/terraform/keycloak/apps/coinvault/envs/hosted/main.tf)

### Symptom: Argo shows `OutOfSync`

Check:

- whether the local apply was pushed to Git
- whether a rollout restart changed only runtime state
- whether the app repo code change was rebuilt/imported but the GitOps repo still references old expectations

## Review checklist for a new intern

- Read the app repo README first.
- Read the deployment manifest second.
- Read this playbook before touching Keycloak or the cluster.
- Confirm whether the change is:
  - app code only
  - manifest only
  - identity only
- Use the smallest rollback scope available.

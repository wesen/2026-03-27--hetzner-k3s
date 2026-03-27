---
Title: CoinVault K3s cluster deployment playbook
Ticket: HK3S-0007
Status: active
Topics:
    - coinvault
    - k3s
    - argocd
    - vault
    - vso
    - mysql
    - deployment
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles:
    - Path: gitops/applications/coinvault.yaml
      Note: Defines the Argo CD application that owns the deployment
    - Path: gitops/kustomize/coinvault/deployment.yaml
      Note: Defines the pod env
    - Path: scripts/build-and-import-coinvault-image.sh
      Note: Documents the direct node image import path
    - Path: scripts/seed-coinvault-k3s-vault-secrets.sh
      Note: Documents how the K3s Vault runtime payload is seeded
    - Path: scripts/validate-coinvault-k3s.sh
      Note: Documents the post-rollout smoke validation path
ExternalSources: []
Summary: Detailed cluster-operator playbook for deploying CoinVault through Argo CD, Vault, VSO, MySQL, and Traefik on the Hetzner K3s environment.
LastUpdated: 2026-03-27T21:20:00-04:00
WhatFor: Use this to execute or review the full cluster-side CoinVault deployment on K3s.
WhenToUse: Read this when rolling out CoinVault, debugging a broken deploy, or onboarding a new operator.
---


# CoinVault K3s cluster deployment playbook

## Purpose

This is the cluster-side operator playbook for CoinVault. It explains how the K3s repo turns CoinVault from an application image into a public HTTPS service using Argo CD, Vault, Vault Secrets Operator, MySQL, Keycloak, Traefik, and a persistent volume for local SQLite files.

This playbook is paired with the app-side guide:

- [`02-coinvault-application-repository-argocd-playbook.md`](./02-coinvault-application-repository-argocd-playbook.md)

## Full system model

```text
GitOps repo
  -> Argo CD Application coinvault
    -> Kustomize package gitops/kustomize/coinvault
      -> Namespace + ServiceAccount + PVC + Deployment + Service + Ingress
      -> VaultConnection + VaultAuth + VaultStaticSecret
        -> K3s Vault + Kubernetes auth
          -> Kubernetes Secret objects
            -> CoinVault pod env vars + mounted Pinocchio files
              -> MySQL + OIDC + Traefik-exposed web app
```

The operational rule is simple: debug this stack from left to right.

## Important concrete files

- [`gitops/applications/coinvault.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/coinvault.yaml)
- [`gitops/kustomize/coinvault/kustomization.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/kustomization.yaml)
- [`gitops/kustomize/coinvault/deployment.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/deployment.yaml)
- [`gitops/kustomize/coinvault/vault-auth.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/vault-auth.yaml)
- [`gitops/kustomize/coinvault/vault-static-secret-runtime.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/vault-static-secret-runtime.yaml)
- [`gitops/kustomize/coinvault/vault-static-secret-pinocchio.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/vault-static-secret-pinocchio.yaml)
- [`scripts/seed-coinvault-k3s-vault-secrets.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/seed-coinvault-k3s-vault-secrets.sh)
- [`scripts/build-and-import-coinvault-image.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/build-and-import-coinvault-image.sh)
- [`scripts/validate-coinvault-k3s.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-coinvault-k3s.sh)
- [`vault/policies/kubernetes/coinvault-prod.hcl`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/coinvault-prod.hcl)
- [`vault/roles/kubernetes/coinvault-prod.json`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/coinvault-prod.json)

## Dependency checklist

Before deploying CoinVault, these components must already work:

- K3s node is `Ready`
- Argo CD is up
- Vault is initialized and unsealed
- Vault Kubernetes auth is configured
- Vault Secrets Operator is running
- MySQL is healthy
- the Keycloak client trusts the `coinvault.yolo.scapegoat.dev` callback/origin

## Step-by-step deployment sequence

### Step 1: verify cluster health

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml

kubectl get nodes
kubectl -n argocd get applications
kubectl -n vault get pods
kubectl -n vault-secrets-operator-system get pods
kubectl -n mysql get pods
```

### Step 2: ensure Vault contains the CoinVault secrets

CoinVault needs these Vault paths:

- `kv/apps/coinvault/prod/runtime`
- `kv/apps/coinvault/prod/pinocchio`

Use:

- [`scripts/seed-coinvault-k3s-vault-secrets.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/seed-coinvault-k3s-vault-secrets.sh)

This script is the boundary between old secret continuity and new cluster infrastructure. It preserves the existing runtime/auth payloads while overriding MySQL settings for the cluster-local service.

### Step 3: build and import the app image

The deployment expects the image to exist on the node already.

```bash
export K3S_NODE_HOST=91.98.46.169
./scripts/build-and-import-coinvault-image.sh
```

Verify:

```bash
ssh root@91.98.46.169 "k3s ctr images ls | grep coinvault"
```

### Step 4: render the Kustomize package locally

```bash
kubectl kustomize gitops/kustomize/coinvault
```

This checks the source Argo will apply.

### Step 5: refresh the Argo application

```bash
kubectl apply -f gitops/applications/coinvault.yaml
kubectl -n argocd annotate application coinvault argocd.argoproj.io/refresh=hard --overwrite
```

### Step 6: watch convergence

```bash
kubectl -n argocd get application coinvault \
  -o jsonpath='{.status.sync.status}{"\n"}{.status.health.status}{"\n"}'
kubectl -n coinvault rollout status deployment/coinvault --timeout=180s
```

### Step 7: verify VSO-produced secrets

```bash
kubectl -n coinvault get vaultauth,vaultstaticsecret
kubectl -n coinvault get secret coinvault-runtime coinvault-pinocchio
```

### Step 8: inspect the pod

```bash
kubectl -n coinvault exec -it deploy/coinvault -- sh
```

Inside:

```sh
env | sort | grep '^COINVAULT_'
ls -la /run/secrets/pinocchio
sed -n '1,120p' /run/secrets/pinocchio/profiles.yaml
sed -n '1,120p' /run/secrets/pinocchio/config.yaml
```

### Step 9: validate the public service

```bash
./scripts/validate-coinvault-k3s.sh
curl -fsS https://coinvault.yolo.scapegoat.dev/healthz | jq
curl -I https://coinvault.yolo.scapegoat.dev/auth/login
```

### Step 10: validate the application behavior

The last step is a browser session:

1. open `https://coinvault.yolo.scapegoat.dev`
2. log in through Keycloak
3. check quick stats
4. submit a short chat prompt
5. verify the data views load

## Why each resource exists

### `Application`

Argo’s durable definition of the deployment. Without it, the cluster can drift away from Git.

### `VaultConnection`, `VaultAuth`, `VaultStaticSecret`

These three resources define:

- where Vault is
- how the workload authenticates
- which Vault paths should materialize into Kubernetes secrets

### `PersistentVolumeClaim`

CoinVault still uses local SQLite for timeline and turns state. That data must survive pod restarts.

### `Deployment`

Connects the image, env vars, secret mounts, PVC, health checks, and service account into a runnable pod.

### `Ingress`

Exposes the app at `https://coinvault.yolo.scapegoat.dev`.

## Important lessons from this rollout

### Service-link env collisions

If Kubernetes service links are enabled, the pod can receive env vars like `COINVAULT_PORT=tcp://...`, which can collide with application config parsing. The deployment therefore disables service links explicitly.

### Profile registry parsing bugs can look like provider/API failures

The OpenAI 401 issue was not caused by networking. It was caused by the app silently loading the wrong profile registry because env-plus-flag merged values were not normalized correctly.

### PVC sync-wave deadlocks are real

With `WaitForFirstConsumer` storage, Argo can deadlock if the PVC is ordered before the Deployment that needs it.

### Data migration is a real part of application migration

Getting the pod healthy was not enough. The app still failed until the local MySQL dataset was imported into the cluster `gec` schema.

## Troubleshooting map

```text
Argo not Synced/Healthy
  -> inspect Application + resource ordering

Pod not starting
  -> inspect image import, env parsing, secret existence

Pod healthy but app broken
  -> inspect mounted profiles/config, MySQL schema, OIDC redirects

Public endpoint broken
  -> inspect ingress, cert-manager/TLS, DNS
```

## Practical commands reference

```bash
kubectl -n argocd get application coinvault -o yaml
kubectl -n coinvault logs deploy/coinvault --tail=200
kubectl -n coinvault get secret coinvault-runtime -o json | jq -r '.data | keys[]'
kubectl -n coinvault get secret coinvault-pinocchio -o json | jq -r '.data | keys[]'
kubectl -n mysql exec statefulset/mysql -- sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" gec -e "SHOW TABLES;"'
```

## Main takeaway

The cluster-side CoinVault deployment works because Git, Argo, Vault, VSO, MySQL, Keycloak, and the app repo all agree on the same runtime contract. This playbook exists to make that contract visible. Once you can explain the contract, you can usually debug the deployment without guessing.

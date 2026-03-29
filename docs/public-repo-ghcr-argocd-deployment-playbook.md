---
Title: "Publish Public-Repo Images to GHCR and Deploy Them with Argo CD"
Slug: "public-repo-ghcr-argocd-deployment-playbook"
Short: "Build a public app image in GitHub Actions, publish it to GHCR, pin it in GitOps, and let Argo CD deploy it cleanly."
Topics:
- github
- ghcr
- argocd
- gitops
- kubernetes
- deployment
- docker
Commands:
- git
- gh
- docker
- kubectl
- argocd
Flags: []
IsTopLevel: true
IsTemplate: false
ShowPerDefault: true
SectionType: Tutorial
---

## What This Page Covers

This page explains the long-term deployment pattern we want for small public application repositories such as `mysql-ide`. The goal is to teach a new intern not just which commands to run, but why the system is split into an application repository, an image registry, and a separate GitOps repository.

The pattern is:

- the app repository builds and publishes a container image
- GitHub Actions pushes that image to GitHub Container Registry (GHCR)
- the GitOps repository pins a specific immutable image tag
- Argo CD reconciles the Kubernetes manifests that reference that tag

This is the clean replacement for the earlier single-node shortcut where we built an image locally and imported it directly into K3s containerd with `imagePullPolicy: Never`.

## The Target Architecture

The full runtime flow looks like this:

```text
Application repo
  -> GitHub Actions workflow
    -> docker buildx build
      -> GHCR image tags
        -> GitOps repo image reference
          -> Argo CD Application
            -> Kubernetes Deployment
              -> running pod on K3s
```

That separation matters because these are different responsibilities:

- application repo: source code, tests, Dockerfile, release workflow
- registry: image storage and distribution
- GitOps repo: declared deployment state
- Argo CD: continuous reconciliation into the cluster

If you collapse these layers mentally, it becomes very hard to reason about what changed when a deployment breaks.

## The Concrete Example in This Environment

The live example for this pattern is `mysql-ide`.

Application repository:

- [`/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml`](/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml)
- [`/home/manuel/code/wesen/2026-03-27--mysql-ide/Dockerfile`](/home/manuel/code/wesen/2026-03-27--mysql-ide/Dockerfile)
- [`/home/manuel/code/wesen/2026-03-27--mysql-ide/README.md`](/home/manuel/code/wesen/2026-03-27--mysql-ide/README.md)

GitOps repository:

- [`/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml)
- [`/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/coinvault.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/coinvault.yaml)

Current live image shape:

- `ghcr.io/wesen/2026-03-27--mysql-ide:sha-<git-sha>`

That `sha-...` tag is important. It is immutable enough for operator work, reviewable in Git, and easy to roll back by reverting one manifest change.

## Core Concepts

### Application Repo vs GitOps Repo

The application repo should answer:

- how do we build the binary
- how do we test it
- how do we package it into an image

The GitOps repo should answer:

- which exact image version should be deployed
- with which Kubernetes manifests
- into which namespace and hostname

Do not put deployment truth only inside the app repo if Argo CD is watching a separate infra repo. Argo only knows what the GitOps repo tells it.

### Why GHCR

GHCR is a good fit for public GitHub repositories because:

- it is close to the source repository
- GitHub Actions can push using `GITHUB_TOKEN`
- public pulls are straightforward once the package visibility is set correctly
- OCI metadata is displayed cleanly

You could use Docker Hub or another registry, but GHCR keeps the workflow small.

### Why Argo CD Should Not Build Images

Argo CD is a deployment controller, not a build system.

It should:

- fetch manifests
- compare desired state to live state
- apply and prune resources

It should not be the place where compilers, tests, and container builds happen. If you force Argo into that role, you mix release engineering with reconciliation and make both harder to debug.

### Why We Pin Image Tags in Git

The safest early-stage workflow is to pin a specific image tag in GitOps, for example:

```yaml
image: ghcr.io/wesen/2026-03-27--mysql-ide:sha-2c3003f
imagePullPolicy: IfNotPresent
```

This gives you:

- explicit rollout history
- easy code review
- easy rollback
- a clear mapping from GitOps commit to running image

Later, you can automate the tag bump with CI-created pull requests. Do not start with hidden automation if the team is still learning the deployment model.

## Preconditions

Before you start, verify these assumptions:

- the application repository is on GitHub
- the repository is public, or you have a private-package pull strategy ready
- the app has a working `Dockerfile`
- the cluster already runs Argo CD
- the GitOps repo already contains an `Application` and Kustomize package for the workload
- the cluster can pull public images from GHCR

For this repository, those assumptions are already true for `mysql-ide`.

## Step 1: Prepare the Application Repository

The application repository needs to be buildable and testable on a clean GitHub runner.

At minimum you want:

- a `Dockerfile`
- a test command that can run non-interactively
- a stable module/dependency lock state
- a public GitHub remote

For `mysql-ide`, the important files are:

- [`/home/manuel/code/wesen/2026-03-27--mysql-ide/Dockerfile`](/home/manuel/code/wesen/2026-03-27--mysql-ide/Dockerfile)
- [`/home/manuel/code/wesen/2026-03-27--mysql-ide/go.mod`](/home/manuel/code/wesen/2026-03-27--mysql-ide/go.mod)
- [`/home/manuel/code/wesen/2026-03-27--mysql-ide/main.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/main.go)

Your mental checklist should look like this:

```text
Can GitHub Actions clone the repo?
Can it run tests?
Can it build the image without local machine secrets?
Can another operator understand the build inputs from the repo alone?
```

## Step 2: Add OCI Metadata to the Dockerfile

The image should identify itself clearly in the registry.

Example pattern:

```dockerfile
LABEL org.opencontainers.image.title="mysql-ide"
LABEL org.opencontainers.image.description="Read-only CoinVault MySQL operator IDE"
LABEL org.opencontainers.image.source="https://github.com/wesen/2026-03-27--mysql-ide"
```

Why this matters:

- registry pages become understandable
- operators can tell what package they are looking at
- OCI metadata helps future automation and audit work

If you skip this, the image still runs, but the operational surface gets worse.

## Step 3: Add the GitHub Actions Publish Workflow

The workflow should do four jobs:

- check out the repo
- run tests
- build the image
- push the image to GHCR on `main`

The live example is:

- [`/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml`](/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml)

The essential structure is:

```yaml
name: publish-image

on:
  pull_request:
  push:
    branches:
      - main

permissions:
  contents: read
  packages: write

jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-go@v6
      - run: go test ./...
      - uses: docker/setup-buildx-action@v4
      - uses: docker/metadata-action@v6
      - uses: docker/login-action@v4
      - uses: docker/build-push-action@v7
```

Important implementation notes:

- `pull_request` should build and test, but usually not push
- `push` on `main` should push
- use `packages: write` so `GITHUB_TOKEN` can push to GHCR
- build `linux/amd64` unless you know you need more architectures

## Step 4: Tag Images in a Way Operators Can Use

Use tags that are human-meaningful and rollback-friendly.

For this repo, the workflow emits:

- `sha-<git-sha>`
- `main`
- `latest`

The deployment should use the immutable-looking SHA tag, not `latest`.

Important implementation detail:

- the tag you pin in GitOps must exactly match the tag that the workflow publishes
- do not assume the deployment updater should use the full `github.sha` string if the publish step emits a shortened `sha-<7 chars>` tag

In this environment, the first live `mysql-ide` rollout failed because the CI-created PR pinned:

```text
ghcr.io/wesen/2026-03-27--mysql-ide:sha-4757a354464846d36cb52c1b5af0bd89a4fcffea
```

but GHCR had actually published:

```text
ghcr.io/wesen/2026-03-27--mysql-ide:sha-4757a35
```

The result was an `ImagePullBackOff` in Kubernetes. The fix was to make the GitOps PR job derive the same short-SHA tag shape that the publish step emits.

Why:

- `latest` is ambiguous
- `main` is useful for humans browsing GHCR
- `sha-...` is the right deployment pin

Recommended operator rule:

- registry may publish convenience tags
- GitOps must pin a specific SHA tag

## Step 5: Make Sure the Package Is Publicly Pullable

This is the step people often forget.

A public GitHub repository does not automatically guarantee that the GHCR package is pullable the way you expect. Check package visibility in GitHub and test an anonymous pull.

Validation example:

```bash
docker pull ghcr.io/wesen/2026-03-27--mysql-ide:sha-2c3003f
```

If that pull fails from a clean environment, Kubernetes on the cluster will likely fail too unless you configure an image pull secret.

## Step 6: Update the GitOps Manifest

Once the image exists in GHCR, change the deployment manifest in the GitOps repo.

For the current cluster, that file is:

- [`/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml)

Change the image reference from the old local-import style:

```yaml
image: mysql-ide:hk3s-0010
imagePullPolicy: Never
```

to the registry-backed style:

```yaml
image: ghcr.io/wesen/2026-03-27--mysql-ide:sha-2c3003f
imagePullPolicy: IfNotPresent
```

This is the key conceptual handoff:

```text
Before:
local laptop build -> ssh import -> node-local image cache -> pod starts

After:
GitHub Actions build -> GHCR package -> cluster pull -> pod starts
```

## Step 7: Push the GitOps Change and Let Argo Reconcile

After you commit the manifest change in the GitOps repo, Argo CD should detect it and sync.

That assumes the `Application` object already exists in the cluster.

For an existing app such as `coinvault`, that is already true, so a merged GitOps PR is enough for Argo to notice the new image pin.

For a brand-new app, there is a one-time bootstrap step first:

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export KUBECONFIG=$PWD/kubeconfig-<server-ip>.yaml

kubectl apply -f gitops/applications/<app>.yaml
kubectl -n argocd annotate application <app> argocd.argoproj.io/refresh=hard --overwrite
```

This repo does not currently auto-create every `Application` from the `gitops/applications/` directory, so the very first deployment of a new app always needs that initial apply.

Useful checks:

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml

kubectl -n argocd get application coinvault \
  -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{"\n"}'

kubectl -n coinvault get deploy mysql-ide -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

If you need to force a quick refresh:

```bash
kubectl -n argocd annotate application coinvault argocd.argoproj.io/refresh=hard --overwrite
```

The target end state is:

- Argo: `Synced Healthy`
- Deployment image: the exact GHCR `sha-...` tag you committed

## Step 8: Validate the Running Application

Do not stop at “the pod is running.” Validate the real operator contract.

For `mysql-ide`, the useful checks are:

```bash
curl -fsSL https://coinvault-sql.yolo.scapegoat.dev/healthz
kubectl -n coinvault get pods
kubectl -n coinvault logs deploy/mysql-ide --tail=100
```

Behavioral validation should include:

- the ingress is reachable
- OIDC login still works
- the app can reach the expected backing service
- no secret or image pull errors appear in pod events

In this environment, the real-world validation included logging in through Keycloak and confirming the schema browser showed the expected `gec` database.

## Rollback Strategy

Rollback should be boring.

If a newly published image is bad:

1. edit the GitOps deployment manifest
2. set the image back to the previous known-good `sha-...` tag
3. commit and push
4. let Argo CD reconcile

That is another reason not to deploy `latest`.

Pseudocode for the release/rollback loop:

```text
publish image in app repo
  -> verify package exists in GHCR
  -> change image tag in GitOps repo
  -> Argo syncs
  -> validate runtime

if validation fails:
  -> revert GitOps image tag to previous SHA
  -> Argo syncs previous image
```

## Troubleshooting

### Symptom: Argo is `Synced` but the pod still uses the old image

Possible causes:

- Kubernetes did not restart the pod because the tag did not actually change
- the manifest change was applied in the wrong overlay or wrong file
- you are looking at a different namespace or deployment than the one Argo manages

Checks:

```bash
kubectl -n coinvault get deploy mysql-ide -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n argocd get application coinvault -o jsonpath='{.status.summary.images}{"\n"}'
```

### Symptom: Image pull fails

Possible causes:

- GHCR package is not public
- image tag does not exist
- registry path does not match the repository name

Checks:

```bash
docker pull ghcr.io/wesen/2026-03-27--mysql-ide:sha-2c3003f
kubectl -n coinvault describe pod <pod-name>
```

### Symptom: GitHub Action builds but does not push

Possible causes:

- workflow is running on `pull_request`
- `packages: write` permission is missing
- `docker/login-action` is gated incorrectly

Check the workflow file and the GitHub Actions run logs:

- [`/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml`](/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml)

### Symptom: The deployment still expects a locally imported image

Possible causes:

- manifest still says `imagePullPolicy: Never`
- image still points to a local-only tag like `mysql-ide:hk3s-0010`

Fix the GitOps manifest rather than importing another image by hand. The whole point of this pattern is to leave the manual node-import flow behind.

## Long-Term Improvement Path

This page describes the recommended first stable pattern, not the final possible automation level.

Recommended maturity path:

1. GitHub Actions builds and pushes images to GHCR
2. operators manually bump `sha-...` tags in the GitOps repo
3. later, CI can open GitOps pull requests automatically
4. only later, if the number of services justifies it, consider Argo CD Image Updater

This order keeps the system understandable while the platform is still being established.

## See Also

- [`docs/argocd-app-setup.md`](./argocd-app-setup.md)
- [`docs/coinvault-k3s-deployment-playbook.md`](./coinvault-k3s-deployment-playbook.md)
- [`docs/hetzner-k3s-server-setup.md`](./hetzner-k3s-server-setup.md)

---
Title: GitHub Actions and GHCR implementation plan for mysql-ide
Ticket: HK3S-0011
Status: active
Topics:
    - coinvault
    - k3s
    - gitops
    - github
    - ghcr
    - ci-cd
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/wesen/2026-03-27--mysql-ide/Dockerfile
      Note: Build input for the future CI workflow
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml
      Note: Target deployment manifest that needs registry image changes
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/build-and-import-mysql-ide-image.sh
      Note: Manual workflow to retire from the default path
ExternalSources: []
Summary: Detailed phased implementation plan for moving mysql-ide to GitHub Actions builds and GHCR-backed Argo CD deployment.
LastUpdated: 2026-03-27T18:02:00-04:00
WhatFor: Use this when actually implementing the GitHub Actions and GHCR route after the design ticket is approved.
WhenToUse: Read this before changing the mysql-ide release pipeline or the K3s deployment manifest.
---

# GitHub Actions and GHCR implementation plan for mysql-ide

## Purpose

This playbook turns the design recommendation into an implementation sequence that a new intern can actually execute. The ordering matters because there are two different repos and two different kinds of risk:

- app-repo CI risk
- cluster deployment risk

The safest path is to make the registry path real first, then cut the deployment over second.

## High-level sequence

```text
prepare app repo CI
  -> publish first GHCR image
  -> verify registry pullability
  -> update K3s manifest
  -> let Argo deploy registry-backed image
  -> retire manual import from default workflow
```

## Phase 1: prepare the app repo for CI publishing

Repository:

- `/home/manuel/code/wesen/2026-03-27--mysql-ide`

### Tasks

1. Create `.github/workflows/publish-image.yaml`
2. Add workflow steps for:
   - checkout
   - Go setup
   - `go test ./...`
   - Docker metadata generation
   - GHCR login
   - buildx image build and push
3. Set workflow permissions:
   - `contents: read`
   - `packages: write`
4. Decide exact image name:
   - expected default: `ghcr.io/wesen/mysql-ide`
5. Define tags:
   - `sha-<shortsha>`
   - `main`
   - optional `latest`

### Validation

- open a PR and confirm the workflow can:
  - run tests
  - build the image
  - skip publish on PR
- merge to `main` and confirm:
  - image appears in GHCR

### Pseudocode

```text
on pull_request:
  run tests
  run docker build

on push main:
  run tests
  compute tags
  login ghcr
  build and push image
```

## Phase 2: verify the registry contract

Before touching the K3s manifests, verify that the registry artifact is usable.

### Tasks

1. Confirm the package exists in GHCR.
2. Confirm the tags exist.
3. If using public visibility:
   - verify anonymous pull works
4. If using private visibility:
   - create the future `imagePullSecret` plan before switching the cluster

### Validation commands

Example local smoke:

```bash
docker pull ghcr.io/wesen/mysql-ide:main
docker run --rm -p 8080:8080 ghcr.io/wesen/mysql-ide:main
curl http://localhost:8080/healthz
```

The exact runtime env vars may still be needed for a meaningful local run, but the pull itself should succeed.

## Phase 3: update the GitOps repo to use registry images

Repository:

- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s`

### Tasks

1. Update [mysql-ide-deployment.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml):
   - replace `mysql-ide:hk3s-0010`
   - replace `imagePullPolicy: Never`
2. Prefer immutable image tags in Git.
3. Optionally move the tag to a Kustomize `images:` override block.
4. Keep the rest of the deployment contract unchanged:
   - env vars
   - Service
   - Ingress
   - OIDC settings
   - DB secret references

### Recommended first manifest shape

```yaml
image: ghcr.io/wesen/mysql-ide:sha-<gitsha>
imagePullPolicy: IfNotPresent
```

### Validation

1. `kubectl kustomize gitops/kustomize/coinvault`
2. push manifest change
3. verify Argo sync
4. verify pod pulls image from GHCR
5. verify `https://coinvault-sql.yolo.scapegoat.dev/healthz`

## Phase 4: decide how image tags move through Git

This is a policy choice more than a coding task.

### Option 1: manual tag bumps

Best first implementation.

Process:

1. GitHub Actions publishes image
2. operator edits GitOps image tag
3. PR merge
4. Argo deploys

### Option 2: app repo CI opens a GitOps PR

Best second implementation if manual bumps become annoying.

Process:

1. GitHub Actions publishes image
2. action edits the GitOps repo image tag
3. action opens a PR
4. human reviews and merges
5. Argo deploys

### Option 3: Argo CD Image Updater

Best only after the simpler model is stable and well understood.

## Phase 5: retire the manual import workflow from the default path

Do not delete the current script immediately. First demote it from “normal deployment path” to “break-glass or local iteration path.”

Current script:

- [build-and-import-mysql-ide-image.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/build-and-import-mysql-ide-image.sh)

### Recommended policy

- normal path:
  - GitHub Actions + GHCR + GitOps + Argo
- exceptional path:
  - local build + node import for emergency debugging only

This is a useful transition because it lets you keep one emergency tool without pretending it is the platform standard.

## Rollback plan

If the first GHCR-backed deployment is bad:

1. revert the GitOps image tag commit
2. Argo syncs the previous image
3. verify `Synced Healthy`
4. investigate the bad image in the app repo CI history

If the registry path itself is broken:

1. temporarily restore the previous known-good image reference
2. only use the manual import path if absolutely necessary
3. fix CI or registry configuration before trying again

## Intern checklist

Before implementation:

- understand the difference between build, registry, and deploy
- read the Dockerfile
- read the current deployment manifest
- read the current manual import script

During implementation:

- verify the workflow on PR before merge
- verify the first published image in GHCR before changing the cluster
- change only the image-delivery layer, not the runtime contract

After implementation:

- confirm Argo is `Synced Healthy`
- confirm the service still logs in and reaches MySQL
- update the operator playbook for the new release path

## Deliverables expected from the follow-up implementation ticket

- `.github/workflows/publish-image.yaml` in the app repo
- GHCR package for `mysql-ide`
- registry-backed image reference in the K3s manifest
- updated deployment playbook that no longer treats node import as the normal path

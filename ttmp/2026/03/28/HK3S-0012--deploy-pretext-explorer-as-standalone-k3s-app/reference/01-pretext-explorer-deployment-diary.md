---
Title: Pretext explorer deployment diary
Ticket: HK3S-0012
Status: active
Topics:
    - pretext
    - gitops
    - argocd
    - static-site
    - kubernetes
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/others/pretext/package.json
      Note: Source-side build command registration for the explorer-only artifact
    - Path: /home/manuel/code/others/pretext/scripts/build-explorer-site.ts
      Note: Source-side static build script created during the rollout
    - Path: /home/manuel/code/others/pretext/Dockerfile.explorer
      Note: Source-side container packaging
    - Path: gitops/kustomize/pretext/deployment.yaml
      Note: Cluster deployment manifest
    - Path: scripts/build-and-import-pretext-explorer-image.sh
      Note: Local image import helper used for the rollout
ExternalSources: []
Summary: ""
LastUpdated: 2026-03-28T14:47:01.400684108-04:00
WhatFor: ""
WhenToUse: ""
---

# Pretext explorer deployment diary

## Goal

Capture the step-by-step deployment work for the standalone Pretext Explorer app, including what was inspected, what changed in each repository, how the cluster rollout was performed, and what validation signals were used.

## Context

This rollout depends on two repositories:

- source repo: `/home/manuel/code/others/pretext`
- deployment repo: `/home/manuel/code/wesen/2026-03-27--hetzner-k3s`

There is also upstream design context in the source repo ticket:

- `/home/manuel/code/others/pretext/ttmp/2026/03/28/PRETEXT-20260328--pretext-architecture-and-intern-onboarding-guide/index.md`

## Quick Reference

### Step 1: Inspect the source page and build path

- confirmed the requested page is `pages/demos/explorer.html`
- confirmed the interactive logic is in `pages/demos/explorer.ts`
- confirmed `bun build pages/demos/explorer.html --outdir /tmp/pretext-explorer-test` emits a self-contained bundle with one HTML file and one hashed JS asset

### Step 2: Source-side packaging in `wesen/pretext`

- added `site:build:explorer` to `package.json`
- added `scripts/build-explorer-site.ts`
- added `Dockerfile.explorer`
- added `.dockerignore`
- validated:
  - `bun run site:build:explorer`
  - `docker build -f Dockerfile.explorer -t pretext-explorer:hk3s-0012 .`

### Step 3: GitOps-side deployment prep

- added `gitops/applications/pretext.yaml`
- added `gitops/kustomize/pretext/{namespace,deployment,service,ingress,kustomization}.yaml`
- added `scripts/build-and-import-pretext-explorer-image.sh`
- added `scripts/validate-pretext-explorer.sh`

### Pending live rollout

- push source changes to `wesen/pretext`
- import image into the K3s node
- apply the Argo application
- validate sync, ingress, TLS, and public response

### TLS gotcha discovered during rollout

- Traefik’s self-signed certificate appears immediately when the ingress exists but cert-manager has not issued the real cert yet
- normal replacement time is usually on the order of tens of seconds to a few minutes
- in this rollout, the self-signed cert persisted because the ingress mistakenly referenced `cert-manager.io/cluster-issuer: letsencrypt-production`
- the actual cluster issuer name is `letsencrypt-prod`
- symptom chain:
  - `curl https://pretext.yolo.scapegoat.dev` failed with a self-signed certificate error
  - `kubectl -n pretext describe certificaterequest pretext-explorer-tls-1` reported `Referenced "ClusterIssuer" not found`
  - `kubectl get clusterissuer` showed only `letsencrypt-prod`

## Usage Examples

### Build the explorer image locally

```bash
cd /home/manuel/code/others/pretext
bun run site:build:explorer
docker build -f Dockerfile.explorer -t pretext-explorer:hk3s-0012 .
```

### Import into the K3s node

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export K3S_NODE_HOST=<server-ip>
./scripts/build-and-import-pretext-explorer-image.sh
```

### Validate the deployed app

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export KUBECONFIG=$PWD/kubeconfig-<server-ip>.yaml
./scripts/validate-pretext-explorer.sh
```

## Related

- `../design-doc/01-pretext-explorer-deployment-design-and-implementation-plan.md`
- `/home/manuel/code/others/pretext/ttmp/2026/03/28/PRETEXT-20260328--pretext-architecture-and-intern-onboarding-guide/design-doc/02-interactive-pretext-explorer-blog-post.md`

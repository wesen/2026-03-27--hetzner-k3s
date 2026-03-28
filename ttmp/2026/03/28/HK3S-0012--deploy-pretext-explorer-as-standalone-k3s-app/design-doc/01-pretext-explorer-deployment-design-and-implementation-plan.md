---
Title: Pretext explorer deployment design and implementation plan
Ticket: HK3S-0012
Status: active
Topics:
    - pretext
    - gitops
    - argocd
    - static-site
    - kubernetes
DocType: design-doc
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/others/pretext/pages/demos/explorer.html
      Note: The interactive article content that will become the public root page
    - Path: /home/manuel/code/others/pretext/pages/demos/explorer.ts
      Note: Browser-side interactive logic bundled into the standalone page
    - Path: /home/manuel/code/others/pretext/scripts/build-explorer-site.ts
      Note: Static build entrypoint for the explorer-only deployment artifact
    - Path: /home/manuel/code/others/pretext/Dockerfile.explorer
      Note: Explorer-specific image packaging
    - Path: gitops/applications/pretext.yaml
      Note: Argo CD application for the deployment
    - Path: gitops/kustomize/pretext/kustomization.yaml
      Note: Kustomize package root for the standalone app
    - Path: scripts/build-and-import-pretext-explorer-image.sh
      Note: Operator helper used for the first rollout on the single-node cluster
ExternalSources: []
Summary: ""
LastUpdated: 2026-03-28T14:47:01.343056028-04:00
WhatFor: ""
WhenToUse: ""
---

# Pretext explorer deployment design and implementation plan

## Executive Summary

We are deploying the `Pretext Explorer` article as a standalone static application at `https://pretext.yolo.scapegoat.dev`. The implementation uses the existing `pretext` TypeScript/Bun source tree to build a self-contained HTML+JS bundle, packages that bundle into a tiny container image, and deploys the image through a new Argo CD `Application` in the K3s repo.

This intentionally does not deploy the entire `pretext` demo site. The explorer page already reads like an interactive essay, so the cleanest operator story is:

- build only `pages/demos/explorer.html`
- rename it to `index.html`
- serve it as a static site
- expose it on its own hostname

That gives us a low-complexity public deployment with no runtime server code, no secret management, and minimal operational failure modes.

## Problem Statement

The source page lives inside the `pretext` development/demo setup, not as a production deployment. We need to turn it into a durable public artifact on the K3s cluster while preserving the interactive behavior and keeping the resulting operational system easy for a new engineer to reason about.

The main constraints are:

- the page is authored as Bun/TypeScript HTML entrypoint content, not a prebuilt asset
- the K3s repo should own deployment truth, not the app repo
- the cluster already has wildcard DNS for `*.yolo.scapegoat.dev`
- the page is static and does not need a backend service
- the first rollout should optimize for simplicity and debuggability rather than maximal CI automation

## Proposed Solution

The deployment has two layers.

### Layer 1: Source packaging in `wesen/pretext`

Add an explorer-specific build path:

- `scripts/build-explorer-site.ts`
- `bun run site:build:explorer`
- `Dockerfile.explorer`

The build script compiles `pages/demos/explorer.html`, rewrites the output root page to `site-explorer/index.html`, and leaves the hashed JS asset beside it. The Dockerfile uses Bun only in the build stage, then copies the static output into an Nginx runtime image.

### Layer 2: GitOps ownership in the K3s repo

Add a dedicated Argo application and namespace:

- `gitops/applications/pretext.yaml`
- `gitops/kustomize/pretext/*`

That package contains:

- namespace
- deployment
- service
- ingress

The ingress exposes `pretext.yolo.scapegoat.dev` and requests TLS from the already-running cluster issuer.

### First-rollout image strategy

For the first rollout, use the same operator-friendly single-node image import path already used elsewhere in this repo:

- build image locally from `/home/manuel/code/others/pretext`
- import into the node’s `k3s` containerd
- deploy with `imagePullPolicy: Never`

This is not the final ideal image-distribution story, but it is the fastest safe way to get the static app live on the existing cluster without adding GHCR or CI work in the middle of the deployment slice.

## Design Decisions

### Deploy the explorer page, not the whole demo site

Reason:

- the user asked for `pages/demos/explorer.html` as a standalone app
- the explorer page is already a complete narrative artifact
- keeping the deployment surface narrow reduces maintenance and review cost

### Use a dedicated `pretext` namespace and Argo application

Reason:

- this is a public app, not a debug sidecar or subcomponent of another app
- a dedicated namespace makes logs, ingress, and lifecycle clearer
- the Argo object boundary stays easy to explain to an intern

### Use a static container rather than a Bun runtime server

Reason:

- the built output is plain static assets
- Nginx is simpler and smaller at runtime
- there is no reason to run Bun in production for this page

### Use the existing wildcard DNS and cluster issuer

Reason:

- `*.yolo.scapegoat.dev` already points at the cluster
- this avoids a Terraform detour unless the wildcard no longer covers the host
- the actual live `ClusterIssuer` name on this cluster is `letsencrypt-prod`, which must match the ingress annotation exactly

### Keep the initial image delivery local to the single node

Reason:

- fastest path to a real deployment
- consistent with existing repo patterns
- GHCR/CI can be added later as a follow-up if the page becomes an actively iterated app

## Alternatives Considered

### Deploy via GitHub Pages only

Rejected because:

- the request is explicitly for the K3s environment and `pretext.yolo.scapegoat.dev`
- it would create split hosting models between cluster apps and static article apps

### Deploy the entire demo site under the hostname

Rejected because:

- broader scope than requested
- introduces extra routing and UX decisions
- weakens the “interactive blog post” framing

### Build a small Bun or Node web server for the page

Rejected because:

- unnecessary runtime complexity
- static files are sufficient

### Pause and build a full GHCR/Actions pipeline first

Deferred because:

- correct long-term direction, but not required for the initial rollout
- would slow down the deployment slice with CI concerns unrelated to the actual app behavior

## Implementation Plan

1. Inspect the existing `pretext` build and confirm Bun emits a self-contained bundle for `pages/demos/explorer.html`.
2. Add the explorer-only static build script and container packaging in `wesen/pretext`.
3. Validate the bundle and Docker image locally.
4. Commit the source-side changes in the `wesen/pretext` fork.
5. Add a dedicated `pretext` Argo application and Kustomize package in the K3s repo.
6. Add operator helper scripts for image import and smoke validation.
7. Build and import the image into the live K3s node.
8. Apply the Argo application, wait for sync, and validate the public site over HTTPS.
9. Record the rollout in the diary and close the ticket.

## Open Questions

Open questions after the initial rollout:

- should this move to GHCR and GitHub Actions once the deployment stabilizes?
- should the `pretext` repo eventually publish the whole demo site as a cluster app too?
- should the public page gain a small landing header or link back to the broader demo index?
- should the repo standardize a shared ingress snippet or documentation pattern so future apps cannot accidentally use the nonexistent `letsencrypt-production` issuer name?

## References

- `/home/manuel/code/others/pretext/ttmp/2026/03/28/PRETEXT-20260328--pretext-architecture-and-intern-onboarding-guide/index.md`
- `/home/manuel/code/others/pretext/ttmp/2026/03/28/PRETEXT-20260328--pretext-architecture-and-intern-onboarding-guide/design-doc/02-interactive-pretext-explorer-blog-post.md`

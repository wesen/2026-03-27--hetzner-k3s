---
Title: Image pipeline investigation diary
Ticket: HK3S-0011
Status: active
Topics:
    - coinvault
    - k3s
    - gitops
    - github
    - ghcr
    - ci-cd
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml
      Note: Confirmed current node-local image contract during Step 1
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/build-and-import-mysql-ide-image.sh
      Note: Confirmed current manual image import path during Step 1
    - Path: /home/manuel/code/wesen/2026-03-27--mysql-ide/Dockerfile
      Note: Build input inspected during Step 2
ExternalSources:
    - https://docs.github.com/en/actions/use-cases-and-examples/publishing-packages/publishing-docker-images
    - https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
Summary: Chronological research diary for designing the GitHub Actions and GHCR image pipeline for mysql-ide.
LastUpdated: 2026-03-27T18:02:00-04:00
WhatFor: Capture what was inspected, what was learned, and why the GitHub Actions plus GHCR route was recommended.
WhenToUse: Read this when continuing HK3S-0011 or reviewing the reasoning behind the recommendation.
---

# Image pipeline investigation diary

## Goal

Record the research behind the decision to replace the current manual `mysql-ide` image import path with GitHub Actions builds and GHCR-backed Argo CD deployment.

## Step 1: confirm how mysql-ide is deployed today

The first question was whether the current mysql-ide deployment was already close to a registry-backed shape or whether it was still a pure one-off debug rollout. Reading the live deployment manifest answered that immediately: it is still intentionally tied to a node-local image.

In [mysql-ide-deployment.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml), the pod uses:

- `image: mysql-ide:hk3s-0010`
- `imagePullPolicy: Never`

That means Kubernetes is not expected to contact any registry at all. The image must already exist in containerd on the K3s node.

### What I did

- Read:
  - [mysql-ide-deployment.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml)
  - [build-and-import-mysql-ide-image.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/build-and-import-mysql-ide-image.sh)

### What I learned

- The live deployment still depends on the manual image-import shortcut.
- The current rollout story is cluster-specific and node-specific.
- The next problem to solve is clearly image distribution, not application wiring.

### Why it matters

This confirmed that a new ticket should focus on pipeline architecture, not on app behavior. The application itself already works. The fragile part is how its runtime artifact gets to the cluster.

## Step 2: confirm the app repo is now remote-backed and inspect the build input

The next question was whether the `mysql-ide` repo was still local-only. Earlier in the rollout work, it had no Git remote. By the time this ticket started, that had changed.

Running `git remote -v` in `/home/manuel/code/wesen/2026-03-27--mysql-ide` showed:

- `origin git@github.com:wesen/2026-03-27--mysql-ide.git`

That matters because it makes GitHub Actions a realistic next step. Without a remote repo, CI design would have been premature.

I also confirmed there was still no `.github/workflows/` directory, which means the design should assume greenfield CI rather than extending an existing workflow.

I inspected the current [Dockerfile](/home/manuel/code/wesen/2026-03-27--mysql-ide/Dockerfile) to verify that the app is already in a CI-friendly shape:

- multi-stage build
- Go build in a `golang` builder
- distroless runtime image
- fixed binary entrypoint

### What I did

- Checked the app repo remote
- Verified the absence of existing GitHub Actions
- Read the Dockerfile

### What I learned

- The repo is now in the right place organizationally for GitHub Actions.
- The build input is already good enough for CI publishing.
- No extra packaging rework is needed before adding a workflow.

### Why it matters

This reduced the scope of the future implementation ticket. The work is not “first make the Dockerfile CI-safe.” It is “add CI and switch deployment over.”

## Step 3: compare build-system options and choose the right boundary

The user asked the key architectural question directly: should the long-term path use GitHub Actions, ask Argo CD to do more, or install another service for builds?

That is the real design decision behind this ticket.

I compared three categories:

- GitHub Actions + GHCR
- Argo CD plus image automation
- in-cluster build systems like Tekton or similar

The recommendation became clear quickly because the current platform already has a clean GitOps boundary:

- Argo manages cluster desired state
- app repos hold source and build inputs

That means the cleanest next step is:

- CI builds outside the cluster
- registry stores the artifact
- GitOps declares the artifact version
- Argo deploys it

### What I learned

- Argo CD should stay a deploy/reconcile tool.
- Asking Argo to “do the build” is the wrong mental model.
- Installing an in-cluster builder now would solve a problem GitHub Actions can already solve with less complexity.

### Why it matters

This is the most important architecture conclusion for a new intern. “Deployment” is not one system. It is:

- build
- registry
- desired state
- reconciliation

Mixing them too early makes the platform harder to operate.

## Step 4: choose the recommended rollout policy

Once GitHub Actions + GHCR was clearly the right platform choice, there was still a smaller but important policy question: how should the GitOps repo learn about new image tags?

The main options were:

- manual Git update
- CI-created PR into the GitOps repo
- Argo CD Image Updater

I recommend a staged approach:

1. first get GHCR publishing working
2. use explicit Git tag updates in the K3s repo
3. later, if the friction is real, automate that with PRs or Image Updater

### What I learned

- The first need is clarity and reviewability, not maximum automation.
- Introducing a second controller before the basic registry path exists would be premature.

### Why it matters

This keeps the follow-up implementation ticket small and likely to succeed. The system can evolve later, but the first registry-backed version should be easy to understand and easy to debug.

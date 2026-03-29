---
Title: CI-created GitOps pull requests and standard app packaging layout
Ticket: HK3S-0013
Status: active
Topics:
    - ci-cd
    - github
    - ghcr
    - argocd
    - gitops
    - kubernetes
    - packaging
DocType: design-doc
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../2026-03-27--mysql-ide/.github/workflows/publish-image.yaml
      Note: Existing app-repo GHCR publish workflow that proves the release half of the model
    - Path: ../../../../../../../2026-03-27--mysql-ide/README.md
    - Path: docs/public-repo-ghcr-argocd-deployment-playbook.md
      Note: Current manual GHCR-to-Argo deployment standard that this ticket extends
    - Path: gitops/applications/argocd-public.yaml
      Note: Representative infrastructure self-hosting application manifest
    - Path: gitops/applications/coinvault.yaml
      Note: Representative real-application Argo CD ownership surface
    - Path: gitops/applications/pretext.yaml
      Note: Representative public stateless app application manifest
ExternalSources: []
Summary: The recommended long-term deployment model is for application repos to build and publish immutable GHCR images in GitHub Actions, then open GitOps pull requests against this K3s repo to update pinned image tags, while this repo adopts a standard packaging contract for public apps, internal tools, platform apps, and shared data services.
LastUpdated: 2026-03-28T23:38:19.545092319-04:00
WhatFor: Explain the target CI/CD and packaging architecture for the migration platform in a way a new intern can use to implement future services consistently.
WhenToUse: Use when standardizing a new service, replacing manual image bumps, or deciding how app repos should interact with this GitOps repo.
---


# CI-created GitOps pull requests and standard app packaging layout

## Executive Summary

The cluster already has the important primitives in place:

- application repositories can build and publish images to GHCR
- this repository is the GitOps source of truth watched by Argo CD
- workloads such as `mysql-ide`, `coinvault`, `pretext`, `vault`, and `keycloak` already prove the runtime stack works

What is missing is standardization.

Today, image publishing and deployment are split correctly in principle, but still inconsistent in practice:

- `mysql-ide` publishes a GHCR image automatically, but the GitOps image bump is still manual
- application package layouts differ depending on who implemented them and when
- infrastructure apps, public apps, internal tools, and shared data services do not yet share one obvious repo contract

The recommended end state is:

1. each app repository owns build, test, Docker packaging, and image publishing
2. each successful `main` build creates a pull request against this GitOps repo to bump one immutable image tag
3. Argo CD continues to deploy only what this repo declares
4. this repo adopts one standard packaging layout with small variations by app type rather than ad hoc directory design

That gives the team:

- explicit reviewable deployments
- rollback by reverting one GitOps commit
- less manual operator toil
- a clear template for interns adding new services

## Problem Statement

The migration platform is now operational, but it still contains a transitional gap between release engineering and deployment engineering.

The gap has two parts.

### Part 1: Image release automation stops too early

The current GHCR pattern, documented in [`docs/public-repo-ghcr-argocd-deployment-playbook.md`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/public-repo-ghcr-argocd-deployment-playbook.md), already gives us:

- GitHub Actions image builds
- public GHCR images
- immutable SHA tags

But the rollout path still requires a human to edit this repo and change:

```yaml
image: ghcr.io/<org>/<repo>:sha-<new-sha>
```

That is not wrong, but it means:

- every release requires manual copying of the new SHA tag
- the app repo and GitOps repo are not linked by an auditable machine-generated handoff
- the process is easy to forget or perform inconsistently

### Part 2: App packaging is not standardized enough

The repo currently has several package shapes:

- public standalone app: [`gitops/kustomize/pretext`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/pretext)
- real app plus helper tool: [`gitops/kustomize/coinvault`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault)
- platform service with secrets/bootstrap jobs: [`gitops/kustomize/keycloak`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak)
- shared data service: [`gitops/kustomize/postgres`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/postgres)
- infrastructure app that manages Argo itself: [`gitops/kustomize/argocd-public`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/argocd-public)

Those shapes are understandable, but they are not yet codified as a contract. A new intern cannot look at the tree and confidently know:

- which files are mandatory
- how services should be named
- when to split a helper surface into its own package versus keep it inside another app package
- how secrets, ingress, service accounts, and image fields should be handled consistently

## Current State Inventory

This section maps the relevant current evidence.

### What already works

- `mysql-ide` publishes to GHCR via [`publish-image.yaml`](/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml)
- the GitOps repo pins the published image tag in a Kubernetes deployment manifest
- Argo CD deploys the pinned tag through an `Application`
- the public route pattern is proven for:
  - `coinvault`
  - `pretext`
  - `argocd-public`

### What is still manual

- updating the image tag in this repo after a successful app build
- deciding the directory/package shape of a new service
- deciding the minimum file set for a new app package

### What the `mysql-ide` example teaches us

From [`publish-image.yaml`](/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml):

- `pull_request` builds and tests without pushing
- `push` to `main` pushes to GHCR
- tags include:
  - `sha-<git-sha>`
  - `main`
  - `latest`

From [`mysql-ide-deployment.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml):

- the deployment uses an immutable SHA tag
- the cluster does not need a local image import anymore
- the registry path is now part of the declared desired state

This is the right foundation. It just needs the final handoff automation.

## Goals

- Make app repo `main` builds produce a reviewable GitOps pull request automatically.
- Keep Argo CD as a deploy/reconcile system only.
- Keep immutable image tags pinned in Git.
- Standardize app packaging so new services follow a predictable layout.
- Preserve easy rollback, operator review, and repo ownership boundaries.

## Non-Goals

- Do not make Argo CD build images.
- Do not install a heavyweight in-cluster CI system now.
- Do not replace Terraform with a new identity/config control plane in this ticket.
- Do not auto-merge deployment PRs in the first version.

## Proposed Solution

The proposed solution has two coordinated parts.

### Part A: CI creates GitOps pull requests

Each application repository will:

1. run tests on pull requests
2. build and publish an image on `main`
3. determine the immutable `sha-<git-sha>` tag
4. clone or patch the GitOps repository
5. update the correct deployment manifest
6. open a pull request instead of pushing directly to `main`

The GitOps repo remains the deployment authority.

The app repo becomes the release initiator, not the deployment authority.

### Part B: Standardize package layout by service type

This repo should define a small number of package contracts.

#### Contract 1: Public stateless app

Use for:

- `pretext`
- future simple public web apps

Required files:

- `namespace.yaml`
- `deployment.yaml`
- `service.yaml`
- `ingress.yaml`
- `kustomization.yaml`
- `gitops/applications/<app>.yaml`

#### Contract 2: Public app with Vault/VSO-managed secrets

Use for:

- `coinvault`

Required files:

- `namespace.yaml`
- `serviceaccount.yaml`
- `vault-connection.yaml`
- `vault-auth.yaml`
- one or more `vault-static-secret-*.yaml`
- `deployment.yaml`
- `service.yaml`
- `ingress.yaml`
- `kustomization.yaml`
- `gitops/applications/<app>.yaml`

#### Contract 3: Platform service with bootstrap jobs

Use for:

- `keycloak`
- future services that need database/user/bootstrap setup

Required files:

- the Vault/VSO secret files from Contract 2
- job-specific service account/auth files
- `*-script-configmap.yaml`
- `*-bootstrap-job.yaml`
- service and deployment
- ingress if public
- `kustomization.yaml`
- `gitops/applications/<app>.yaml`

#### Contract 4: Shared data service

Use for:

- `postgres`
- `mysql`
- `redis`

Required files:

- `namespace.yaml`
- `serviceaccount.yaml`
- `vault-connection.yaml`
- `vault-auth.yaml`
- `vault-static-secret.yaml`
- `headless-service.yaml` where needed
- `service.yaml`
- `statefulset.yaml`
- `kustomization.yaml`
- `gitops/applications/<service>.yaml`

#### Contract 5: Infrastructure self-hosting package

Use for:

- `argocd-public`

Required files:

- only the resources truly owned by GitOps at runtime
- no accidental coupling to app demo packages

The key rule is:

```text
Own only the resources whose lifecycle belongs to this package.
Do not hide unrelated infrastructure resources inside application packages.
```

## Target Architecture

### Release and deployment flow

```text
app repo push to main
  -> GitHub Actions
    -> test
    -> build image
    -> push ghcr.io/<org>/<repo>:sha-<git-sha>
    -> patch GitOps manifest in a branch
    -> open PR against this repo
      -> human review / merge
        -> Argo CD detects new desired image tag
          -> rollout in cluster
```

### Ownership model

```text
Application repo
  - source code
  - tests
  - Dockerfile
  - GitHub Actions image publish workflow
  - GitOps PR creation workflow

GitOps repo
  - Kubernetes manifests
  - pinned image tags
  - Argo CD Applications
  - runtime topology

Argo CD
  - compares GitOps repo to cluster
  - applies desired state
  - prunes removed objects
```

## Detailed Design

### The PR-creation workflow

The app repo workflow should use a dedicated credential capable of opening pull requests in this repo.

The clean first version is:

- store a fine-scoped GitHub token or GitHub App credentials in the app repo secrets
- use a script step to:
  - clone this repo
  - edit one image field
  - create a branch
  - commit
  - push
  - open a pull request

Pseudo-flow:

```text
on push to main:
  image_tag = "sha-" + current_commit
  target_file = map_app_to_gitops_file(app_name)
  patch image field in target_file
  if no diff:
    stop
  create branch ci/<app>/<image_tag>
  commit "chore(<app>): bump image to <image_tag>"
  push branch
  open PR with rollout context
```

### Where the mapping should live

Do not bury the app-to-file mapping in shell logic that only one operator understands.

Use one of these explicit options:

1. one small config file in the app repo
2. one small config file in this repo
3. a convention-driven path if the app package is standardized enough

Recommended first version:

- each app repo owns a small config file that says:
  - GitOps repo URL
  - target branch
  - target manifest file
  - image field path

This is the least ambiguous for the first implementation.

### How the manifest patching should work

The patching layer should be deterministic.

Do not use freehand `sed` against YAML if a structured edit is easy.

Preferred order:

1. `yq` structured edit
2. a tiny Go or Python updater script with tests
3. `sed` only if the file contract is extremely fixed

Example logical patch:

```text
load deployment.yaml
find spec.template.spec.containers[name=<app>].image
replace image tag only
write file back
```

### Review boundary

The CI-created pull request should not auto-merge initially.

Reviewers should check:

- correct target file
- correct image tag
- no unrelated manifest drift
- changelog or PR body explains what application commit produced the image

The PR body should include:

- app repo commit SHA
- image tag
- workflow run URL
- target manifest file
- rollback instruction

### Rollback design

Rollback should remain trivial:

- revert the GitOps PR merge commit, or
- open a second PR that resets the image tag to the previous SHA

This is one of the reasons to prefer GitOps PRs over auto-mutating in-cluster tools at this stage.

## Design Decisions

### Decision 1: Use GitHub Actions plus GitOps PRs

Why:

- works with the existing GitHub-hosted repos
- keeps the cluster free of CI credentials and build systems
- preserves explicit review

### Decision 2: Keep immutable image pins in Git

Why:

- strongest operator visibility
- easy rollback
- clean audit trail

### Decision 3: Standardize package layout by category, not by forcing one shape for everything

Why:

- a public stateless app is not the same as a shared data service
- some variation is legitimate
- the contract should reduce ambiguity without becoming fake purity

### Decision 4: Keep Argo CD out of image-building

Why:

- Argo is the reconciliation layer
- builds belong in CI
- mixing them complicates failure analysis

## Alternatives Considered

### Alternative 1: Keep manual image bumps forever

Pros:

- very simple
- no extra credentials

Cons:

- scales poorly
- relies on operator memory
- weakens app-repo to GitOps handoff

Decision: reject as the long-term standard.

### Alternative 2: Use Argo CD Image Updater

Pros:

- less custom workflow logic
- can automate tag tracking

Cons:

- adds another controller
- harder for interns to reason about at first
- can hide rollout causality if adopted too early

Decision: postpone until the simpler PR model is proven.

### Alternative 3: Let Argo build images

Pros:

- one system in theory

Cons:

- wrong tool
- poor separation of concerns
- harder debugging

Decision: reject.

### Alternative 4: Install in-cluster CI such as Tekton now

Pros:

- self-hosted build system
- potentially powerful

Cons:

- too much platform weight right now
- unnecessary complexity for the current scale

Decision: reject for now.

## Implementation Plan

### Phase 1: Define the standard packaging contract

- write one packaging guide in `docs/`
- classify current packages into the five contracts above
- identify small naming/structure cleanups needed to conform

### Phase 2: Implement the first CI-created GitOps PR path

- choose one app, recommended: `mysql-ide`
- add a workflow that opens PRs against this repo after successful publish
- use a narrow credential and a deterministic updater

### Phase 3: Validate operator ergonomics

- inspect the PR readability
- inspect rollback clarity
- confirm Argo sync behavior after merge

### Phase 4: Generalize

- template the workflow for future app repos
- adopt the package contract for the next migrated app

## Open Questions

- Should the updater use `yq`, a small Go helper, or a repo-local script in each app repo?
- Should branch naming and PR body be standardized centrally?
- When should Argo CD Image Updater be reconsidered?
- Should helper surfaces like `mysql-ide` stay nested inside a parent app package or graduate into their own application package later?

## Recommended Order of Execution

1. Write the packaging standard into `docs/`
2. Implement PR automation for `mysql-ide`
3. Observe one or two successful rollouts
4. Apply the same pattern to the next public app repo

## References

- [`docs/public-repo-ghcr-argocd-deployment-playbook.md`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/public-repo-ghcr-argocd-deployment-playbook.md)
- [`gitops/applications/coinvault.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/coinvault.yaml)
- [`gitops/applications/pretext.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/pretext.yaml)
- [`gitops/applications/argocd-public.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/argocd-public.yaml)
- [`publish-image.yaml`](/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml)
- [`README.md`](/home/manuel/code/wesen/2026-03-27--mysql-ide/README.md)

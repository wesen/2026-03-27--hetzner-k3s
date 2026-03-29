---
Title: Implementation plan for GitOps PR automation and app packaging standardization
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
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles:
    - /home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml
    - /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml
    - /home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/public-repo-ghcr-argocd-deployment-playbook.md
ExternalSources: []
Summary: This playbook gives the phased operator sequence for standardizing application packaging and implementing CI-created GitOps pull requests, starting with mysql-ide as the first concrete target.
LastUpdated: 2026-03-28T23:38:19.62638733-04:00
WhatFor: Provide an actionable implementation sequence for adopting the design safely.
WhenToUse: Use when beginning the actual implementation of HK3S-0013.
---

# Implementation plan for GitOps PR automation and app packaging standardization

## Purpose

This playbook explains how to implement the target state described in the design document without destabilizing the current cluster.

The implementation sequence is intentionally conservative:

- standardize the contract first
- automate one app repo second
- evaluate the operator experience third
- generalize only after the first path is proven

## Environment Assumptions

- this repository remains the Argo CD source of truth
- application repositories live on GitHub
- application repositories can publish images to GHCR
- the cluster can pull public GHCR images
- GitHub credentials needed for opening pull requests can be stored as repo or org secrets

Local tools expected for operator work:

- `git`
- `gh`
- `kubectl`
- `docker`
- `yq` or another structured YAML editor if chosen

## Phase 1: Normalize the packaging contract

### Goal

Write down the standard package shapes and then align future services to them.

### Steps

1. Create a `docs/` help page describing the package contracts.
2. Enumerate the current packages into categories:
   - public stateless app
   - public app with Vault/VSO secrets
   - platform app with bootstrap job
   - shared data service
   - infrastructure self-hosting package
3. For each category, define:
   - mandatory files
   - optional files
   - naming rules
   - namespace rules
   - secret-handling rules
4. Decide whether helper surfaces nested under a parent package are acceptable by default.

### Exit Criteria

- there is one written package contract
- interns can tell where a new service belongs before creating files

## Phase 2: Implement the first CI-created GitOps PR path

### Recommended first target

- `mysql-ide`

Why:

- it already publishes to GHCR
- it is small enough to reason about
- its deployment target is already pinned to an immutable image

### Steps

1. Add or choose a deterministic manifest updater.
2. Add a GitHub Actions job after image publish that:
   - computes `sha-<git-sha>`
   - clones this repo
   - updates the target manifest
   - commits the change on a new branch
   - opens a PR
3. Make the workflow idempotent:
   - no PR if the target file already uses that SHA
4. Include rollout context in the PR body.

### Pseudocode

```text
on successful push-to-main image publish:
  image_tag = "sha-" + commit_sha
  clone gitops repo
  patch target manifest image field
  if file unchanged:
    exit successfully
  create branch
  commit
  push
  open PR
```

### Exit Criteria

- a real app repo opens a clean PR in this repo
- the PR changes only the expected image line

## Phase 3: Review and merge ergonomics

### Goal

Make sure the workflow is pleasant enough that the team will actually use it.

### Checks

- Is the PR title obvious?
- Is the PR body useful?
- Is rollback obvious?
- Does the diff stay minimal?
- Is the source workflow run linked?

### Exit Criteria

- one merged PR successfully rolls out through Argo CD
- one rollback is proven on paper or in a test environment

## Phase 4: Generalize the pattern

### Goal

Turn the first working path into a reusable template.

### Steps

1. Move any reusable updater logic into:
   - a shared script, or
   - a documented workflow template
2. Document the minimum configuration required in future app repos.
3. Apply the same pattern to the next app repo.

### Exit Criteria

- future app repos can adopt the workflow without inventing a new release model

## Commands

These are representative operator commands for the implementation phase.

### Inspect the current live image pin

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
kubectl -n argocd get application coinvault -o jsonpath='{.status.summary.images}{"\n"}'
```

### Inspect the current GHCR publish workflow

```bash
sed -n '1,220p' /home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml
```

### Validate the current GitOps app package shape

```bash
kubectl kustomize gitops/kustomize/coinvault
kubectl kustomize gitops/kustomize/pretext
kubectl kustomize gitops/kustomize/argocd-public
```

### Validate the ticket docs themselves

```bash
docmgr doctor --ticket HK3S-0013 --stale-after 30
```

## Failure Modes

### Failure mode: the app workflow can publish the image but cannot open a PR

Likely cause:

- missing or under-scoped GitHub credential

Response:

- inspect the workflow permissions
- inspect the token or GitHub App installation scope

### Failure mode: the updater changes the wrong file or too much YAML

Likely cause:

- weak path mapping
- text substitution instead of structured edit

Response:

- switch to a structured updater and make the target file path explicit

### Failure mode: a PR merges but Argo does not roll out

Likely cause:

- wrong manifest path
- wrong image field
- app not watched by Argo

Response:

- inspect `Application` source path
- inspect rendered deployment manifest
- inspect the image summary in Argo status

## Exit Criteria

This ticket’s design phase is complete when:

- the target architecture is documented
- the packaging contract is documented
- the first recommended implementation target is identified
- the rollout order is explicit
- the bundle is validated and uploaded to reMarkable

## Notes

- Do not broaden this into Argo CD Image Updater in the first implementation pass.
- Do not collapse app repo release logic into the GitOps repo.
- Do not let “standardization” become a reason to flatten all package types into one fake universal shape.

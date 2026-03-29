---
Title: Investigation diary for GitOps PR automation and packaging standardization
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
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - /home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/public-repo-ghcr-argocd-deployment-playbook.md
    - /home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml
    - /home/manuel/code/wesen/2026-03-27--mysql-ide/README.md
    - /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications
    - /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize
ExternalSources: []
Summary: This diary records the concrete local evidence used to recommend CI-created GitOps pull requests and a categorized app packaging contract.
LastUpdated: 2026-03-28T23:38:26.968307062-04:00
WhatFor: Preserve the reasoning trail behind the design recommendation.
WhenToUse: Use when reviewing how the recommendations were derived from the current repo state.
---

# Investigation diary for GitOps PR automation and packaging standardization

## Goal

Capture the concrete evidence used to design the next release-engineering cleanup step.

## Context

The user asked for the next architectural cleanup after:

- GHCR image publishing had already been proven for `mysql-ide`
- Argo CD was already deploying from this repository
- the remaining pain points were:
  - manual image bumps in GitOps
  - uneven application package layout

## Quick Reference

### Evidence reviewed

- [`docs/public-repo-ghcr-argocd-deployment-playbook.md`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/public-repo-ghcr-argocd-deployment-playbook.md)
  - confirmed the current intended image-publish and GitOps deployment story
- [`publish-image.yaml`](/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml)
  - confirmed that image publish automation already exists
- [`README.md`](/home/manuel/code/wesen/2026-03-27--mysql-ide/README.md)
  - confirmed the repo already documents the manual-to-GHCR transition and current deployment contract
- [`gitops/applications/`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications)
  - confirmed the repo now contains multiple Argo CD apps rather than one demo stack
- [`gitops/kustomize/`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize)
  - confirmed multiple valid but different package shapes

### Concrete findings

1. The release split is already mostly correct.
   App repos own image build and publish. This repo owns deployment state.

2. The missing step is the handoff.
   There is no CI-created pull request that carries the new immutable image tag into this repo.

3. Package layout is coherent but undocumented as a contract.
   The current shapes are explainable, but not yet standardized for future services.

4. Standardization should be category-based.
   Public stateless apps, Vault-backed apps, bootstrap-heavy platform apps, and shared data services should not be forced into a single fake universal directory contract.

## Usage Examples

### How to use this diary when implementing the ticket

- Start with the existing GHCR workflow instead of inventing a new publish model.
- Use `mysql-ide` as the first automation target because it already has the cleanest build/publish setup.
- Derive the package contract from the current repo instead of writing a theoretical standard that ignores `coinvault`, `keycloak`, or `argocd-public`.

## Implementation Notes

### 2026-03-29: First implementation slice started

The first implementation slice turned the high-level design into concrete operator work:

- expanded `HK3S-0013` from analysis-only tasks into implementation tasks
- wrote the operator-facing packaging standard at [`docs/app-packaging-and-gitops-pr-standard.md`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/app-packaging-and-gitops-pr-standard.md)
- anchored the standard around the existing `mysql-ide` GHCR workflow and the current app package categories in this repo

The next implementation slice is in the app repo itself:

- add `deploy/gitops-targets.json`
- add the PR updater script
- extend the GitHub Actions flow so successful `main` builds can propose GitOps image bumps automatically

## Related

- [01-ci-created-gitops-pull-requests-and-standard-app-packaging-layout.md](../design-doc/01-ci-created-gitops-pull-requests-and-standard-app-packaging-layout.md)
- [01-implementation-plan-for-gitops-pr-automation-and-app-packaging-standardization.md](../playbook/01-implementation-plan-for-gitops-pr-automation-and-app-packaging-standardization.md)

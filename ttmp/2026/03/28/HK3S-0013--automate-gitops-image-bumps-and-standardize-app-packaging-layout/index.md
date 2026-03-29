---
Title: Automate GitOps image bumps and standardize app packaging layout
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
DocType: index
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: Define and start implementing the long-term release-engineering pattern for public app repositories: GitHub Actions publishes immutable GHCR images, CI opens pull requests against this GitOps repo to bump pinned image tags, and this repo adopts a standard packaging contract for public apps, internal tools, platform services, and shared data services.
LastUpdated: 2026-03-29T17:40:00-04:00
WhatFor: Capture the recommended next architectural cleanup after manual GHCR image publishing was proven for mysql-ide.
WhenToUse: Use when implementing CI-created GitOps pull requests or deciding how a new service should be packaged in this repo.
---

# Automate GitOps image bumps and standardize app packaging layout

## Overview

This ticket defines the next release-engineering standard for the migration platform.

The two concrete goals are:

- replace manual GitOps image bumps with CI-created pull requests
- standardize application packaging layout so future services do not invent new shapes ad hoc

The first implementation target is now in place:

- this repo contains the operator-facing packaging standard in `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/app-packaging-and-gitops-pr-standard.md`
- `mysql-ide` now carries deploy target metadata, a deterministic GitOps manifest updater, and a release workflow stage that can open PRs once the GitHub secret boundary is configured
- the first live CI-created GitOps PR now exists at `wesen/2026-03-27--hetzner-k3s#1`

The design is grounded in the current working examples:

- GHCR publishing in `/home/manuel/code/wesen/2026-03-27--mysql-ide`
- Argo CD application ownership in `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications`
- current Kustomize package shapes in `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize`

## Key Links

- [Design Doc](./design-doc/01-ci-created-gitops-pull-requests-and-standard-app-packaging-layout.md)
- [Implementation Playbook](./playbook/01-implementation-plan-for-gitops-pr-automation-and-app-packaging-standardization.md)
- [Investigation Diary](./reference/01-investigation-diary-for-gitops-pr-automation-and-packaging-standardization.md)

## Status

Current status: **active**

Implementation state:

- design complete
- operator docs complete
- `mysql-ide` packaging scaffold complete
- local updater validation complete
- first live validation complete: `mysql-ide` CI opened PR `#1` against this GitOps repo
- remaining work is rollout to additional services, not proving the pattern

## Topics

- ci-cd
- github
- ghcr
- argocd
- gitops
- kubernetes
- packaging

## Tasks

See [tasks.md](./tasks.md) for the current task list.

## Changelog

See [changelog.md](./changelog.md) for recent changes and decisions.

## Structure

- design/ - Architecture and design documents
- reference/ - Prompt packs, API contracts, context summaries
- playbooks/ - Command sequences and test procedures
- scripts/ - Temporary code and tooling
- various/ - Working notes and research
- archive/ - Deprecated or reference-only artifacts

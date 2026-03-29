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
Summary: Define the long-term release-engineering pattern for public app repositories: GitHub Actions publishes immutable GHCR images, CI opens pull requests against this GitOps repo to bump pinned image tags, and this repo adopts a standard packaging contract for public apps, internal tools, platform services, and shared data services.
LastUpdated: 2026-03-28T23:38:19.448818453-04:00
WhatFor: Capture the recommended next architectural cleanup after manual GHCR image publishing was proven for mysql-ide.
WhenToUse: Use when implementing CI-created GitOps pull requests or deciding how a new service should be packaged in this repo.
---

# Automate GitOps image bumps and standardize app packaging layout

## Overview

This ticket defines the next release-engineering standard for the migration platform.

The two concrete goals are:

- replace manual GitOps image bumps with CI-created pull requests
- standardize application packaging layout so future services do not invent new shapes ad hoc

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

---
Title: Design a release orchestration CLI for source-to-GitOps app deployments
Ticket: HK3S-0019
Status: complete
Topics:
    - gitops
    - argocd
    - ghcr
    - github
    - operations
    - kubernetes
    - cli
DocType: index
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/source-app-deployment-infrastructure-playbook.md
      Note: Current deployment-system source of truth the proposed CLI should compress operationally
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/app-packaging-and-gitops-pr-standard.md
      Note: Existing CI-created GitOps PR standard this ticket builds on
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/get-kubeconfig-tailscale.sh
      Note: Existing cluster access helper the proposed CLI should reuse in phase 1
ExternalSources: []
Summary: "Ticket workspace for designing a single operator CLI that reduces manual polling across source CI, GHCR, GitOps PRs, Argo CD, Kubernetes rollout state, and public verification."
LastUpdated: 2026-03-30T11:05:00-04:00
WhatFor: "Use this ticket to design and later implement a release-oriented operator CLI for the K3s platform."
WhenToUse: "Read this when you need the high-level summary, entry points, and document map for the release orchestration CLI proposal."
---

# Design a release orchestration CLI for source-to-GitOps app deployments

## Overview

This ticket proposes a new operator CLI, tentatively named `hk3sctl`, to reduce the amount of manual command sequencing needed for a normal source-to-GitOps deployment on this platform.

The motivating scenario was the `pretext-trace` rollout, where a single change required repeated manual use of:

- `gh run ...`
- `docker manifest inspect ...`
- `gh pr ...`
- Tailscale kubeconfig recovery
- `kubectl` Argo and rollout checks
- authenticated and unauthenticated `curl` verification

The deliverables in this ticket do three things:

1. explain the current system and why the operator surface is still noisy,
2. propose a concrete CLI design with verbs, target metadata, and phased implementation,
3. preserve the real commands and scenarios that led to the design.

## Key Links

- Design guide:
  - `design-doc/01-release-orchestration-cli-design-and-implementation-guide.md`
- Investigation diary:
  - `reference/01-investigation-diary-for-release-orchestration-cli-design.md`
- Task list:
  - `tasks.md`

## Status

Current status: **complete**

## Topics

- gitops
- argocd
- ghcr
- github
- operations
- kubernetes
- cli

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

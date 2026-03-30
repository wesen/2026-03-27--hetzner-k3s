---
Title: Design a JavaScript automation runtime for source-to-GitOps release operations
Ticket: HK3S-0020
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
    - Path: docs/app-packaging-and-gitops-pr-standard.md
      Note: Existing GitOps PR contract the runtime must preserve
    - Path: docs/source-app-deployment-infrastructure-playbook.md
      Note: |-
        Current source-to-GitOps deployment model this runtime is meant to automate
        Canonical deployment model the runtime needs to automate
    - Path: gitops/applications/pretext-trace.yaml
      Note: Concrete Argo application used in the motivating scenario
    - Path: gitops/kustomize/pretext-trace/deployment.yaml
      Note: Concrete GitOps workload target for the runtime design
    - Path: scripts/get-kubeconfig-tailscale.sh
      Note: |-
        Existing cluster-auth helper that the runtime can wrap in phase 1
        Current cluster-auth helper the phase-1 runtime can wrap
    - Path: ttmp/2026/03/30/HK3S-0019--design-a-release-orchestration-cli-for-source-to-gitops-app-deployments/design-doc/01-release-orchestration-cli-design-and-implementation-guide.md
      Note: Sibling ticket covering the command-oriented alternative
ExternalSources: []
Summary: Ticket workspace for designing a JS/TS release automation runtime that exposes source, registry, GitOps, Argo, cluster, and verification subsystems as programmable APIs.
LastUpdated: 2026-03-30T11:18:00-04:00
WhatFor: Use this ticket to design and later implement a snippet-driven automation runtime for K3s release operations.
WhenToUse: Read this when you want the high-level summary and document map for the JS automation runtime proposal.
---


# Design a JavaScript automation runtime for source-to-GitOps release operations

## Overview

This ticket proposes a programmable alternative to the CLI in HK3S-0019.

The core idea is:

- instead of only giving operators fixed commands,
- give them stable JavaScript APIs over the same real subsystems,
- so they can write short snippets for release tasks, verification, conditional merges, rollout checks, and ad hoc diagnostics.

The motivating scenario is still the `pretext-trace` rollout, because that is the freshest and most concrete example of the current operator friction:

- source push,
- workflow wait,
- image existence check,
- GitOps PR detection and merge,
- Tailscale kubeconfig recovery,
- Argo refresh,
- rollout wait,
- and public verification.

## Key Links

- Design guide:
  - `design-doc/01-javascript-release-automation-runtime-design-and-implementation-guide.md`
- Investigation diary:
  - `reference/01-investigation-diary-for-javascript-release-automation-runtime-design.md`
- Tasks:
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

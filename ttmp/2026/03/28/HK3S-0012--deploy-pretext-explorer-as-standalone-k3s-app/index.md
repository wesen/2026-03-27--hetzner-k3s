---
Title: Deploy Pretext explorer as standalone K3s app
Ticket: HK3S-0012
Status: active
Topics:
    - pretext
    - gitops
    - argocd
    - static-site
    - kubernetes
DocType: index
Intent: long-term
Owners: []
RelatedFiles:
    - Path: gitops/applications/pretext.yaml
      Note: Argo CD application for the standalone Pretext deployment
    - Path: gitops/kustomize/pretext/deployment.yaml
      Note: Static web deployment manifest for the explorer app
    - Path: gitops/kustomize/pretext/ingress.yaml
      Note: Public hostname and TLS wiring for pretext.yolo.scapegoat.dev
    - Path: scripts/build-and-import-pretext-explorer-image.sh
      Note: Local operator helper for building and importing the image into the single-node cluster
    - Path: scripts/validate-pretext-explorer.sh
      Note: Smoke validation for Argo status and public response checks
ExternalSources: []
Summary: ""
LastUpdated: 2026-03-28T14:47:01.275508085-04:00
WhatFor: ""
WhenToUse: ""
---

# Deploy Pretext explorer as standalone K3s app

## Overview

This ticket tracks the deployment of the interactive `Pretext Explorer` article at `pretext.yolo.scapegoat.dev` as a standalone static web app on the Hetzner K3s cluster. The work is split across two repositories:

- `wesen/pretext` produces the static artifact and container image
- `wesen/2026-03-27--hetzner-k3s` owns the cluster manifests, Argo CD application, and operator rollout steps

The deployment goal is deliberately narrower than “publish the full demo site.” We want a single-purpose public experience that opens directly into the explorer article, keeps the runtime surface tiny, and is easy to roll back.

## Key Links

- Design doc: `design-doc/01-pretext-explorer-deployment-design-and-implementation-plan.md`
- Diary: `reference/01-pretext-explorer-deployment-diary.md`
- Source context ticket in the app repo: `/home/manuel/code/others/pretext/ttmp/2026/03/28/PRETEXT-20260328--pretext-architecture-and-intern-onboarding-guide/index.md`
- App source page: `/home/manuel/code/others/pretext/pages/demos/explorer.html`
- App source module: `/home/manuel/code/others/pretext/pages/demos/explorer.ts`

## Status

Current status: **active**

Current implementation state:

- source-side standalone explorer build is implemented in the `pretext` repo
- container packaging for the static site is implemented in the `pretext` repo
- GitOps manifests and operator scripts are added in this repo
- the app is live at `https://pretext.yolo.scapegoat.dev`
- Argo reports `pretext` as `Synced Healthy`
- the first rollout also documented the cluster-specific TLS issuer requirement: use `letsencrypt-prod`

## Topics

- pretext
- gitops
- argocd
- static-site
- kubernetes

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

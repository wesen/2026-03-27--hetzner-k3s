---
Title: Build mysql-ide images with GitHub Actions and GHCR for Argo CD deployment
Ticket: HK3S-0011
Status: active
Topics:
    - coinvault
    - k3s
    - gitops
    - github
    - ghcr
    - ci-cd
DocType: index
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml
      Note: Implemented GitHub Actions workflow that builds and publishes the mysql-ide image to GHCR
    - Path: /home/manuel/code/wesen/2026-03-27--mysql-ide/Dockerfile
      Note: Current build input for the future GitHub Actions workflow
    - Path: /home/manuel/code/wesen/2026-03-27--mysql-ide/README.md
      Note: App runtime guide that future CI and deployment docs should stay aligned with
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml
      Note: Current deployment manifest still tied to node-local images
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/build-and-import-mysql-ide-image.sh
      Note: Current manual image import path targeted by this design
ExternalSources:
    - https://docs.github.com/en/actions/use-cases-and-examples/publishing-packages/publishing-docker-images
    - https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
    - https://argocd-image-updater.readthedocs.io/en/latest/
Summary: Design ticket for moving mysql-ide from manual node-local image imports to GitHub Actions builds, GHCR image storage, and registry-backed Argo CD deployment.
LastUpdated: 2026-03-27T18:18:00-04:00
WhatFor: Use this ticket to design the long-term image build and deployment path for mysql-ide, moving from manual node-local imports to GitHub Actions plus GHCR feeding the existing Argo CD GitOps workflow.
WhenToUse: Read this when implementing or reviewing the registry-backed image delivery path for mysql-ide or using it as the template for later K3s workloads.
---



# Build mysql-ide images with GitHub Actions and GHCR for Argo CD deployment

## Overview

This ticket covers the next platform step after the first live `mysql-ide` deployment. Right now the service works, but its image delivery path is still a single-node shortcut:

- build locally
- `docker save`
- SSH into the Hetzner node
- import the image directly into K3s containerd
- run the manifest with `imagePullPolicy: Never`

That was the right move for the first rollout because it minimized variables while the app and GitOps manifests were still being debugged. It is not the right long-term deployment shape.

The purpose of this ticket is to design the long-term replacement:

- GitHub Actions builds and tests the image in CI
- GitHub Container Registry stores the image
- the K3s GitOps repo references immutable registry images
- Argo CD deploys the image by reconciling Git, not by building anything itself

## Current Step

Step 4 is active: the implementation is complete in both repos, the live cluster is on the GHCR-backed image, and the remaining work is ticket closeout, validation, and publication.

## Key Links

- **Related Files**: See frontmatter RelatedFiles field
- **External Sources**: See frontmatter ExternalSources field
- Design:
  - [01-github-actions-ghcr-image-pipeline-design.md](./design/01-github-actions-ghcr-image-pipeline-design.md)
- Implementation playbook:
  - [01-github-actions-ghcr-implementation-plan.md](./playbooks/01-github-actions-ghcr-implementation-plan.md)
- Investigation diary:
  - [01-image-pipeline-investigation-diary.md](./reference/01-image-pipeline-investigation-diary.md)
- Implementation diary:
  - [02-image-pipeline-implementation-diary.md](./reference/02-image-pipeline-implementation-diary.md)

## Status

Current status: **active**

Current recommendation:

- do not teach Argo CD to build images
- do not install an in-cluster build system yet
- use GitHub Actions in the `mysql-ide` app repo to:
  - run tests
  - build the image
  - push to `ghcr.io`
- update the K3s repo to use immutable registry tags
- keep image rollout declarative through the GitOps repo
- optionally evaluate Argo CD Image Updater later, but only after the basic registry path is stable

Current outcome:

- the ticket now includes:
  - a detailed architecture and tradeoff document
  - a phased implementation plan
  - a chronological investigation diary
- a separate implementation diary now records the actual rollout sequence, GitHub Actions run IDs, Argo refresh behavior, and authenticated browser verification
- the `mysql-ide` app repo now has a working GitHub Actions workflow that publishes to:
  - `ghcr.io/wesen/2026-03-27--mysql-ide`
- the live `mysql-ide` deployment now pulls:
  - `ghcr.io/wesen/2026-03-27--mysql-ide:sha-2c3003f`
- Argo reports the `coinvault` application as:
  - `Synced Healthy`
- `https://coinvault-sql.yolo.scapegoat.dev/healthz` still returns the expected DB and OIDC contract
- `docmgr doctor --ticket HK3S-0011 --stale-after 30` passes
- the bundle is uploaded to reMarkable under `/ai/2026/03/27/HK3S-0011`

## Topics

- coinvault
- k3s
- gitops
- github
- ghcr
- ci-cd

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

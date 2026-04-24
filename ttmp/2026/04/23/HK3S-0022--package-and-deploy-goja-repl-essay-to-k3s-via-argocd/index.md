---
Title: Package and deploy goja-repl essay to K3s via ArgoCD
Ticket: HK3S-0022
Status: complete
Topics:
    - goja
    - goja-repl
    - essay
    - deployment
    - github-actions
    - ghcr
    - gitops
    - argocd
    - kubernetes
DocType: index
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../corporate-headquarters/go-go-goja/.github/workflows/publish-image.yaml
      Note: CI workflow to build
    - Path: ../../../../../../corporate-headquarters/go-go-goja/Dockerfile
      Note: Multi-stage Dockerfile for Node frontend + Go CGO backend + Debian runtime
    - Path: ../../../../../../corporate-headquarters/go-go-goja/Makefile
      Note: Build contract for Go and frontend
    - Path: ../../../../../../corporate-headquarters/go-go-goja/cmd/goja-repl/essay.go
      Note: Go essay command entrypoint
    - Path: ../../../../../../corporate-headquarters/go-go-goja/deploy/gitops-targets.json
      Note: Deployment target metadata for GitOps PR automation
    - Path: ../../../../../../corporate-headquarters/go-go-goja/pkg/repldb/store.go
      Note: SQLite session storage backend
    - Path: ../../../../../../corporate-headquarters/go-go-goja/pkg/replessay/handler.go
      Note: Essay HTTP handler serving page
    - Path: ../../../../../../corporate-headquarters/go-go-goja/scripts/open_gitops_pr.py
      Note: Python script to open GitOps PRs for image bumps
    - Path: ../../../../../../corporate-headquarters/go-go-goja/web/package.json
      Note: Added @types/node devDependency for Vite config type-checking
    - Path: ../../../../../../corporate-headquarters/go-go-goja/web/vite.config.ts
      Note: Vite build config with /static/essay/ base path
    - Path: docs/public-repo-ghcr-argocd-deployment-playbook.md
      Note: GHCR + ArgoCD deployment playbook
    - Path: docs/source-app-deployment-infrastructure-playbook.md
      Note: Source app deployment infrastructure playbook
    - Path: gitops/applications/codebase-browser.yaml
      Note: Reference Argo CD Application manifest
    - Path: gitops/applications/goja-essay.yaml
      Note: Argo CD Application manifest for goja-essay
    - Path: gitops/kustomize/codebase-browser/deployment.yaml
      Note: Reference stateless public app deployment pattern
    - Path: gitops/kustomize/goja-essay/deployment.yaml
      Note: Stateful deployment with SQLite PVC mount at /data
    - Path: gitops/kustomize/goja-essay/ingress.yaml
      Note: Ingress binding goja.yolo.scapegoat.dev
    - Path: gitops/kustomize/goja-essay/pvc.yaml
      Note: PersistentVolumeClaim for SQLite session storage
ExternalSources: []
Summary: ""
LastUpdated: 2026-04-23T20:45:31.765659168-04:00
WhatFor: ""
WhenToUse: ""
---




# Package and deploy goja-repl essay to K3s via ArgoCD

## Overview

This ticket documents the path from the current local `goja-repl essay` command to a public deployment on `goja.yolo.scapegoat.dev` using the same GitHub Actions -> GHCR -> GitOps PR -> Argo CD pattern already used in the Hetzner K3s repo.

The goja-repl essay is an interactive web application that teaches users how the REPL works through live JavaScript sessions. It consists of a Go backend (`cmd/goja-repl/essay.go`, `pkg/replessay/`) and a React frontend (`web/`). Unlike the completely stateless `codebase-browser`, the essay uses SQLite for session persistence, so the GitOps package must include a writable volume.

## Key Links

- **Design doc**: [Implementation guide](./design-doc/01-implementation-guide-deploy-goja-repl-essay-to-k3s.md)
- **App repo**: `/home/manuel/code/wesen/corporate-headquarters/go-go-goja`
- **Infra repo**: `/home/manuel/code/wesen/2026-03-27--hetzner-k3s`
- **Example page**: `https://goja.yolo.scapegoat.dev/essay/meet-a-session`

## Status

Current status: **active**

## Topics

- goja
- goja-repl
- essay
- deployment
- github-actions
- ghcr
- gitops
- argocd
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

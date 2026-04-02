---
Title: Migrate smailnail from Coolify to K3s via GitOps
Ticket: HK3S-0021
Status: active
Topics:
    - argocd
    - ci-cd
    - ghcr
    - gitops
    - keycloak
    - vault
    - migration
DocType: index
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/wesen/corporate-headquarters/smailnail/README.md
      Note: Source repo overview and hosted runtime contract
    - Path: /home/manuel/code/wesen/corporate-headquarters/smailnail/docs/deployments/smailnaild-merged-coolify.md
      Note: Current merged hosted deployment shape
    - Path: /home/manuel/code/wesen/hair-booking/.github/workflows/publish-image.yaml
      Note: Reference release workflow for source repo automation
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/draft-review/deployment.yaml
      Note: Reference K3s deployment pattern for an OIDC app with runtime secrets
    - Path: /home/manuel/code/wesen/terraform/keycloak/apps/smailnail/envs/hosted/main.tf
      Note: Existing hosted Keycloak realm and client definition
ExternalSources: []
Summary: "Ticket bundle for designing the smailnail migration from the current Coolify deployment model into the K3s GitOps platform, including CI/CD, Keycloak, Vault, Argo CD, runtime secrets, and optional Dovecot fixture handling."
LastUpdated: 2026-04-02T09:05:48.11991594-04:00
WhatFor: "Use this ticket to understand the full migration scope for smailnail and to implement it without rediscovering the platform patterns from scratch."
WhenToUse: "Read this before adding source-repo release automation, K3s manifests, Vault wiring, or Keycloak changes for smailnail."
---

# Migrate smailnail from Coolify to K3s via GitOps

## Overview

This ticket documents the remaining Coolify-to-K3s migration work for `smailnail`. The goal is to move the main hosted application onto the K3s platform in the same control-plane model as the other migrated apps:

- source repo owns code, tests, Docker packaging, and GHCR publishing
- source repo opens GitOps pull requests into this infra repo
- this repo owns Argo CD, Kustomize manifests, runtime secret delivery, ingress, and deployment policy
- Keycloak and Vault remain platform services, not app-local one-offs

The main conclusion from the investigation is that the primary migration unit is the merged `smailnaild` server, not the legacy standalone MCP binary. The Dovecot fixture is a separate concern and should be treated as an optional companion slice unless the explicit requirement is "remove every last Coolify workload."

The core deliverable is the design guide:

- [01-smailnail-k3s-migration-design-and-implementation-guide.md](./design-doc/01-smailnail-k3s-migration-design-and-implementation-guide.md)

Supporting investigation log:

- [01-smailnail-migration-diary.md](./reference/01-smailnail-migration-diary.md)

## Key Links

- Design guide: [01-smailnail-k3s-migration-design-and-implementation-guide.md](./design-doc/01-smailnail-k3s-migration-design-and-implementation-guide.md)
- Diary: [01-smailnail-migration-diary.md](./reference/01-smailnail-migration-diary.md)
- Task list: [tasks.md](./tasks.md)
- Changelog: [changelog.md](./changelog.md)

## Status

Current status: **active**

Current state of the work in this ticket:

- analysis complete
- implementation guide written
- implementation still pending in the application, Terraform, and GitOps repositories

## Topics

- argocd
- ci-cd
- ghcr
- gitops
- keycloak
- vault
- migration

## Tasks

See [tasks.md](./tasks.md) for the implementation breakdown. The open tasks are intentionally future-facing because this ticket is a design and migration-planning bundle, not the implementation itself.

## Changelog

See [changelog.md](./changelog.md) for recent changes and decisions.

## Key Findings

- The current source repo already has a production-oriented merged server shape where `smailnaild` serves `/`, `/api/*`, `/auth/*`, `/.well-known/oauth-protected-resource`, and `/mcp`. That is the right runtime to move to K3s.
- The source repo does not yet implement the standard K3s release contract. It has test/lint/release workflows, but it does not yet have `publish-image.yaml`, `deploy/gitops-targets.json`, or a GitOps PR updater script.
- The hosted identity model is already app-local and stable: browser login and MCP bearer auth both resolve a local user by `(issuer, subject)` and then access shared app data through that local user ID.
- The K3s version should use the shared PostgreSQL service and Vault/VSO runtime secret delivery instead of continuing the current SQLite-on-single-host default.
- The Dovecot fixture is not just another HTTP ingress workload. It exposes raw IMAP/POP3/LMTP/ManageSieve ports and should be handled either as a separate migration slice or explicitly left external for now.

## Structure

- design/ - Architecture and design documents
- reference/ - Prompt packs, API contracts, context summaries
- playbooks/ - Command sequences and test procedures
- scripts/ - Temporary code and tooling
- various/ - Working notes and research
- archive/ - Deprecated or reference-only artifacts

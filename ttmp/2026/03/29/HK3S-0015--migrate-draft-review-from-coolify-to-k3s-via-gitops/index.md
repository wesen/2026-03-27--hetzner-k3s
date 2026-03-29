---
Title: Migrate Draft Review from Coolify to K3s via GitOps
Ticket: HK3S-0015
Status: active
Topics:
    - draft-review
    - k3s
    - gitops
    - keycloak
    - postgres
    - ghcr
    - vault
DocType: index
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/wesen/2026-03-24--draft-review/docs/deployments/draft-review-coolify.md
      Note: Current hosted runtime contract on Coolify
    - Path: /home/manuel/code/wesen/2026-03-24--draft-review/Dockerfile
      Note: Current production container shape with embedded frontend
    - Path: /home/manuel/code/wesen/terraform/keycloak/apps/draft-review/envs/hosted/main.tf
      Note: Current hosted Keycloak realm and browser client source of truth
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/source-app-deployment-infrastructure-playbook.md
      Note: Canonical app-onboarding pattern the migration should follow
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/29/HK3S-0014--add-vault-backed-ghcr-image-pull-secret-pattern-for-private-app-images/index.md
      Note: Implemented private GHCR image-pull pattern to reuse for Draft Review
ExternalSources: []
Summary: Recreate Draft Review on the K3s platform using the standardized GHCR, GitOps, Vault, Postgres, and Keycloak patterns already proven with earlier apps.
LastUpdated: 2026-03-29T10:41:37.303986217-04:00
WhatFor: Track the end-to-end migration of Draft Review from the current Coolify deployment to the K3s cluster without losing the existing runtime contract.
WhenToUse: Use when packaging the Draft Review source repo, wiring private image pulls, provisioning its Postgres database and media storage, creating the K3s Keycloak realm/client, and validating the new parallel deployment.
---

# Migrate Draft Review from Coolify to K3s via GitOps

## Overview

This ticket covers the first real migration of `draft-review` from the existing Coolify setup into the Hetzner K3s platform.

The target platform shape is:

- source repo publishes immutable GHCR images through GitHub Actions
- source repo opens GitOps PRs into this repository
- K3s runs Draft Review behind Traefik and cert-manager
- shared cluster PostgreSQL hosts the `draft_review` database
- in-cluster Keycloak hosts the `draft-review` realm and browser client
- Vault and VSO deliver runtime secrets and the GHCR image pull secret

The current assumption for the parallel hostname is:

- `https://draft-review.yolo.scapegoat.dev`

That is the safest migration target because the current Coolify deployment remains at:

- `https://draft-review.app.scapegoat.dev`

## Key Links

- [Migration Design And Implementation Guide](./design/01-draft-review-k3s-migration-design-and-implementation-guide.md)
- [Data And Author Identity Migration Plan](./design/02-draft-review-data-and-author-identity-migration-plan.md)
- [Migration Playbook](./playbooks/01-draft-review-k3s-migration-playbook.md)
- [Implementation Diary](./reference/01-draft-review-k3s-migration-diary.md)

## Status

Current status: **active**

Current scope:

- migration ticket created
- current Coolify runtime contract inspected
- source-repo packaging scaffold merged and GHCR image published
- parallel K3s Keycloak realm/client applied
- Draft Review K3s app is live with valid Let's Encrypt TLS on `draft-review.yolo.scapegoat.dev`
- platform ACME issuer has been restored as a dedicated GitOps-managed app
- Terraform-managed `wesen` user created in the K3s Draft Review realm
- hosted Draft Review data imported into cluster Postgres with target-schema-first normalization
- imported `wesen` author row rewritten to the K3s issuer and K3s Keycloak subject
- browser login as `wesen` now exposes the imported Draft Review content on K3s

## Topics

- draft-review
- k3s
- gitops
- keycloak
- postgres
- ghcr
- vault

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

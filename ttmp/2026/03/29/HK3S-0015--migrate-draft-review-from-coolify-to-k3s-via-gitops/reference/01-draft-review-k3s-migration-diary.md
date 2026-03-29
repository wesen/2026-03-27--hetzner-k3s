---
Title: Draft Review K3s migration diary
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
DocType: reference
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: Chronological diary for the Draft Review migration work.
LastUpdated: 2026-03-29T11:05:00-04:00
WhatFor: Preserve the real implementation trail for the migration.
WhenToUse: Use when reviewing what was done, in what order, and why.
---

# Draft Review K3s migration diary

## 2026-03-29: Ticket opened and current runtime shape inspected

I started by reading the existing hosted deployment docs instead of guessing the runtime contract from memory.

Important findings from the current Coolify deployment:

- public URL is `https://draft-review.app.scapegoat.dev`
- OIDC issuer is `https://auth.scapegoat.dev/realms/draft-review`
- the backend process is `draft-review serve`
- the app needs PostgreSQL plus persistent media storage
- hosted Keycloak config is already managed in Terraform at `keycloak/apps/draft-review/envs/hosted`

Important findings from the source repo:

- the production `Dockerfile` already builds the frontend and embeds it into the Go binary
- there is no GitHub Actions packaging path yet
- there is no `deploy/gitops-targets.json` yet
- the repo is private and currently only documents the Coolify deployment path

That makes Draft Review a good test of the full private-app migration path:

- private GHCR image
- private-image pull secret
- shared Postgres database bootstrap
- K3s Keycloak parallel realm/client
- PVC-backed media directory

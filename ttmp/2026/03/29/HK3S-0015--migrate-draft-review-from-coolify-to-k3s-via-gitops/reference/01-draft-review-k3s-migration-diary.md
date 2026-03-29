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

## 2026-03-29: Source-repo packaging scaffold implemented

The first real implementation slice was the source-repo packaging layer. I deliberately kept this separate from cluster manifests so the release path could be validated in isolation.

Changes made in `/home/manuel/code/wesen/2026-03-24--draft-review`:

- added `.github/workflows/publish-image.yaml`
- added `deploy/gitops-targets.json`
- added `scripts/open_gitops_pr.py`
- updated `README.md` to describe the new GHCR and GitOps PR model

Validation performed:

```bash
go test ./cmd/... ./pkg/... -count=1
docker build -t draft-review:local .
python3 scripts/open_gitops_pr.py --help
```

Observed result:

- Go tests passed
- the production Docker image built successfully, including the frontend embed step
- the PR updater script is executable and exposes the expected CLI

Important implementation note:

- the source repo has many unrelated untracked files already present locally
- only the new packaging files and README changes should be committed for this task

Important operational note:

- the `gitops-pr` workflow is designed to skip cleanly when `GITOPS_PR_TOKEN` is not configured
- that means this packaging task can be merged before the K3s target manifest exists, without breaking the repository’s default workflow behavior

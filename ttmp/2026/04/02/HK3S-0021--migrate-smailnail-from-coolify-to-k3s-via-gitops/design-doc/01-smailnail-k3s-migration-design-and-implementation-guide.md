---
Title: smailnail K3s migration design and implementation guide
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
DocType: design-doc
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../corporate-headquarters/smailnail/Dockerfile
      Note: |-
        Current production image build for the merged hosted server
        Current merged production image build
    - Path: ../../../../../../../corporate-headquarters/smailnail/README.md
      Note: |-
        Source repo overview including hosted runtime, endpoints, and DB options
        Current hosted runtime
    - Path: ../../../../../../../corporate-headquarters/smailnail/pkg/smailnaild/db.go
      Note: Database defaults and schema ownership
    - Path: ../../../../../../../corporate-headquarters/smailnail/pkg/smailnaild/http.go
      Note: |-
        Route registration for the merged web and MCP server
        Route map for web auth
    - Path: ../../../../../../../corporate-headquarters/smailnail/scripts/docker-entrypoint.smailnaild.sh
      Note: |-
        Current environment-variable contract for container startup
        Runtime environment contract for the container
    - Path: ../../../../../../../hair-booking/.github/workflows/publish-image.yaml
      Note: |-
        Source-repo CI/CD reference pattern
        Reference release automation pattern
    - Path: gitops/kustomize/draft-review/deployment.yaml
      Note: |-
        Reference K3s package for a stateful OIDC application
        Reference K3s manifest pattern for stateful OIDC apps
ExternalSources: []
Summary: Detailed intern-facing design for migrating smailnail from the current Coolify deployment model to the K3s platform, including source-repo CI/CD, Keycloak, Vault, Argo CD, runtime secrets, database choice, and optional Dovecot fixture handling.
LastUpdated: 2026-04-02T09:05:48.146110702-04:00
WhatFor: Explain exactly what needs to change in the source repo, Terraform repo, and GitOps repo to move smailnail onto K3s without rediscovering the platform patterns.
WhenToUse: Use this before implementing the smailnail migration, reviewing PRs for that work, or onboarding a new engineer to the deployment path.
---


# smailnail K3s migration design and implementation guide

## Executive summary

`smailnail` is already close to the target platform shape. The source repo has a production-oriented Docker build, a merged hosted server (`smailnaild`) that serves the SPA, the web API, browser OIDC routes, and the MCP endpoint, and a central Terraform-managed Keycloak realm for the application. The missing pieces are not the application runtime itself. The missing pieces are the release and platform integration contract:

- there is no GitHub Actions workflow that publishes immutable GHCR image tags
- there is no `deploy/gitops-targets.json` in the source repo
- there is no GitOps PR updater script in the source repo
- there is no `gitops/kustomize/smailnail` package in this K3s repo
- there is no explicit `smailnail` runtime secret or Argo CD `Application` in this repo
- the current hosted Keycloak Terraform browser-client redirect URIs appear stale relative to the newer merged deployment docs

The recommended migration shape is:

```text
smailnail source repo
  -> GitHub Actions
  -> GHCR image
  -> automated GitOps PR into this repo

this K3s repo
  -> gitops/kustomize/smailnail
  -> Vault/VSO runtime secret
  -> optional Vault/VSO GHCR pull secret
  -> Argo CD Application

platform services
  -> shared PostgreSQL
  -> K3s Keycloak at auth.yolo.scapegoat.dev
  -> Vault + VSO
```

The main app should move first. The hosted Dovecot fixture should be treated as a separate subproblem because it exposes raw TCP mail ports and does not fit the normal HTTP ingress path.

## Problem statement and scope

The remaining migration goal is to remove `smailnail` from the older Coolify deployment model and place it onto the same K3s control planes already used by the other migrated applications.

The user explicitly called out:

- Argo CD
- CI/CD pipeline
- Keycloak
- the remaining Coolify-to-K3s move

That means this ticket is not just about writing a deployment manifest. It must cover the full path from source commit to running K3s workload:

1. how the image is built and published
2. how the desired state is updated in Git
3. how Argo discovers and reconciles the app
4. how runtime secrets are delivered
5. how OIDC stays coherent between browser login and MCP bearer auth
6. how the app state is stored
7. how the rollout is validated and cut over

This ticket is intentionally scoped around the merged hosted server and its platform dependencies. The optional Dovecot fixture is covered as a companion slice, not as a hidden assumption.

## Current-state analysis

### 1. What the source repo currently contains

The source repo is not just a CLI repo anymore. The top-level README says it now contains:

- `smailnail`
- `mailgen`
- `imap-tests`
- `smailnaild`
- `smailnail-imap-mcp`

That is explicit in `/home/manuel/code/wesen/corporate-headquarters/smailnail/README.md:3-22`.

The same README also documents the hosted application shape:

- `smailnaild` exposes account CRUD, mailbox previews, rule CRUD, and dry-runs
- default bind is `0.0.0.0:8080`
- health endpoints include `/healthz` and `/readyz`
- runtime can use either default SQLite or a Postgres DSN

Evidence:

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/README.md:137-190`

That means the runtime already supports the main platform concern that matters most for K3s migration: it is not hard-coded to SQLite. It can already speak Postgres.

### 2. The merged hosted runtime is already the real deployment target

The newer Coolify deployment guide says one `smailnaild` process now serves:

- the SPA
- `/api/*`
- browser login under `/auth/*`
- public MCP metadata at `/.well-known/oauth-protected-resource`
- bearer-protected MCP traffic at `/mcp`

Evidence:

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/deployments/smailnaild-merged-coolify.md:3-20`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/http.go:117-177`

The code matches the docs. `NewHandler` mounts:

- health and info routes
- session-backed API routes
- `/.well-known/oauth-protected-resource`
- `/mcp`
- the SPA handler last

Evidence:

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/http.go:117-145`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/http.go:147-197`

That is important because it resolves one easy migration mistake: the K3s target should not be built around the legacy standalone MCP service first. The merged server is already the intended production shape.

### 3. The container build is already production-oriented

The root Dockerfile:

1. builds the Vite UI
2. copies the UI output into the embedded web asset directory
3. builds `cmd/smailnaild` with `-tags embed`
4. packages a small runtime image

Evidence:

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/Dockerfile:1-40`

The entrypoint also already defines the environment-variable contract for:

- DB type or DSN
- encryption key
- browser OIDC
- MCP enablement and auth mode
- optional scope and audience tightening

Evidence:

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/scripts/docker-entrypoint.smailnaild.sh:8-113`

This is good news. It means the K3s work does not need a new runtime contract. It mostly needs release automation and Kubernetes wiring.

### 4. The app identity model is strong enough for K3s already

The OIDC design docs and code consistently say:

- browser login is server-side OIDC
- the app provisions or refreshes users by `(issuer, subject)`
- sessions are local application state
- MCP bearer auth and browser auth both resolve to the same local user

Evidence:

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/deployments/smailnaild-oidc-keycloak.md:9-17`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/deployments/smailnaild-oidc-keycloak.md:161-174`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/shared-oidc-playbook.md:10-16`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/auth/oidc.go:102-141`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/auth/oidc.go:223-311`

The app schema also reflects that contract. The DB migrations include:

- `imap_accounts`
- `imap_account_tests`
- `rules`
- `rule_runs`
- `users`
- `user_external_identities`
- `web_sessions`

Evidence:

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/db.go:191-255`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/db.go:261-306`

This makes the K3s migration straightforward from an identity perspective. The semantics should be preserved, not redesigned.

### 5. The source repo does not yet follow the K3s release contract

The current `.github/workflows` directory contains:

- `codeql-analysis.yml`
- `dependency-scanning.yml`
- `lint.yml`
- `push.yml`
- `release.yaml`
- `release.yml`
- `secret-scanning.yml`

Evidence:

- directory listing from `/home/manuel/code/wesen/corporate-headquarters/smailnail/.github/workflows`

What is missing:

- no `publish-image.yaml`
- no `deploy/gitops-targets.json`
- no `scripts/open_gitops_pr.py`

Evidence:

- the workflow listing above contains no `publish-image.yaml`
- a repository search for `deploy/gitops-targets.json`, `open_gitops_pr.py`, and `publish-image.yaml` under the repo returned nothing

This is the main source-repo gap. `hair-booking` shows the missing pattern clearly:

- `publish-image.yaml` builds, tests, publishes, and then opens a GitOps PR
- `deploy/gitops-targets.json` tells CI which manifest to patch
- `scripts/open_gitops_pr.py` rewrites the image field and opens the PR

Evidence:

- `/home/manuel/code/wesen/hair-booking/.github/workflows/publish-image.yaml:1-104`
- `/home/manuel/code/wesen/hair-booking/deploy/gitops-targets.json:1-11`
- `/home/manuel/code/wesen/hair-booking/scripts/open_gitops_pr.py:29-125`
- `/home/manuel/code/wesen/hair-booking/scripts/open_gitops_pr.py:238-319`

### 6. The current hosted Keycloak Terraform is partly useful and partly stale

The central Terraform repo already has a hosted `smailnail` environment with:

- realm `smailnail`
- browser client `smailnail-web`
- MCP client `smailnail-mcp`

Evidence:

- `/home/manuel/code/wesen/terraform/keycloak/apps/smailnail/envs/hosted/main.tf:10-49`

But there is a likely mismatch between older hosted Terraform and newer merged-host docs.

The hosted Terraform browser-client redirect URI and origin are:

- `https://smailnail.mcp.scapegoat.dev/auth/callback`
- `https://smailnail.mcp.scapegoat.dev`

Evidence:

- `/home/manuel/code/wesen/terraform/keycloak/apps/smailnail/envs/hosted/main.tf:17-31`

The newer merged-host docs say the browser app host should be:

- `https://smailnail.scapegoat.dev`
- callback `https://smailnail.scapegoat.dev/auth/callback`

Evidence:

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/deployments/smailnaild-merged-coolify.md:16-20`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/deployments/smailnaild-merged-coolify.md:82-96`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/deployments/smailnaild-oidc-keycloak.md:38-52`

That inconsistency must be surfaced early. The K3s migration should not blindly copy forward stale redirect data.

### 7. The Dovecot fixture is real infrastructure, but it is not the main app

The Dovecot Coolify doc says the hosted fixture:

- is a remote IMAP test target
- binds raw ports `24`, `110`, `143`, `993`, `995`, `4190`
- persists `/home` and `/etc/dovecot/ssl`
- uses direct host port bindings rather than an HTTP router

Evidence:

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/deployments/smailnail-dovecot-coolify.md:3-39`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/deployments/coolify/smailnail-dovecot.compose.yaml:1-12`

This matters because a normal K3s app migration using `Ingress` does not solve raw IMAP/TCP exposure. That fixture is operationally separate from the main `smailnaild` web+MCP app.

## Gap analysis

The migration gaps are now clear.

### Source repo gaps

- No image-publish workflow for immutable GHCR tags.
- No GitOps target metadata file.
- No PR opener script.
- No source-repo README section that documents the K3s release path.

### Terraform and Keycloak gaps

- No documented K3s-parallel `smailnail` Keycloak target yet.
- Likely stale browser redirect/origin configuration in the existing hosted Terraform env.
- No explicit migration note that aligns `smailnail` with the K3s Keycloak hostname strategy used elsewhere in this repo.

### GitOps repo gaps

- No `gitops/kustomize/smailnail` package.
- No `gitops/applications/smailnail.yaml`.
- No Vault/VSO runtime secret definition for `smailnail`.
- No decision captured yet on whether the app image will be public or use the private-image pull-secret pattern.

### Platform decision gaps

- SQLite versus shared PostgreSQL has not been fixed for the K3s path.
- The Dovecot fixture scope is ambiguous.
- The final K3s hostname for the app is not explicitly documented in the source repo.

## Proposed solution

## Recommended target architecture

The recommended architecture for the main app is:

```text
browser or MCP client
  -> smailnail.yolo.scapegoat.dev
       -> /           SPA
       -> /auth/*     browser OIDC
       -> /api/*      session-backed API
       -> /mcp        bearer-protected MCP
       -> /.well-known/oauth-protected-resource

smailnail Deployment
  -> runtime secret from Vault/VSO
  -> shared PostgreSQL
  -> shared K3s Keycloak

source repo CI
  -> publish immutable GHCR tag
  -> open GitOps PR in this repo

Argo CD
  -> sync gitops/kustomize/smailnail
```

I am explicitly inferring the K3s app hostname `smailnail.yolo.scapegoat.dev` from the established platform pattern:

- `draft-review.yolo.scapegoat.dev`
- `auth.yolo.scapegoat.dev`
- other K3s-hosted app routes in this repo

That inference is consistent with the existing parallel-host strategy documented for Keycloak:

- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0008--move-shared-keycloak-onto-k3s-under-argo-cd/design-doc/01-keycloak-on-k3s-implementation-design.md:153-176`

If the actual desired hostname is different, the rest of the design still holds. The specific host value must just be propagated consistently through ingress, OIDC redirect URIs, and MCP resource URL settings.

## Major design decisions

### Decision 1: Migrate the merged `smailnaild` app, not the legacy standalone MCP binary

Why:

- the merged server is already the documented preferred production target
- the code already mounts web, auth, API, and MCP together
- a single host is easier to reason about for browser identity and stored-account MCP access

Evidence:

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/deployments/smailnaild-merged-coolify.md:3-20`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/http.go:132-145`

### Decision 2: Use shared PostgreSQL on K3s instead of SQLite for the main app

Why:

- the app already supports DSN-based Postgres operation
- the platform already has a shared PostgreSQL service and a documented bootstrap-job pattern
- using Postgres keeps the K3s app stateless at the filesystem level
- avoiding a SQLite PVC simplifies backup, restore, pod replacement, and future scaling decisions

Evidence:

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/README.md:175-190`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/shared-oidc-playbook.md:189-203`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/vault-backed-postgres-bootstrap-job-pattern.md:27-42`

This is a recommendation, not a statement that SQLite is impossible. The point is operational fit. SQLite works for the current one-host Coolify model because the container and volume live together. K3s is the point where the platform should stop carrying app state in a local file unless there is a strong reason.

### Decision 3: Use Vault/VSO for runtime secrets

The app needs at least:

- database DSN or DB coordinates
- encryption key ID
- encryption key material
- OIDC issuer URL
- OIDC client secret
- OIDC redirect URL
- MCP OIDC issuer/resource URL values if not hard-coded

The container entrypoint already expects environment variables for those settings:

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/scripts/docker-entrypoint.smailnaild.sh:8-113`

The K3s repo already uses `VaultStaticSecret` resources for app runtime secrets:

- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/draft-review/runtime-secret.yaml:1-16`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/keycloak-runtime-secret.yaml:1-17`

`smailnail` should follow that pattern instead of introducing inline literals or ad hoc `Secret` manifests.

### Decision 4: Follow the standardized source-repo release contract

The canonical tutorial in this repo says the source repo should own:

- Docker packaging
- image publishing workflow
- deployment target metadata
- GitOps PR helper

Evidence:

- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/source-app-deployment-infrastructure-playbook.md:48-69`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/source-app-deployment-infrastructure-playbook.md:154-168`

So the right move is not to build special local release glue for `smailnail`. The right move is to add the missing standard files to the source repo.

### Decision 5: Treat the Dovecot fixture as a separate companion workload

The Dovecot fixture is not a normal HTTP app. It needs raw TCP exposure and persistent mail state. That is different enough from the main app that bundling both into one migration step is risky.

Recommended framing:

- primary migration slice: merged `smailnaild`
- optional second slice: hosted Dovecot fixture

This keeps the main application migration tractable and prevents raw-port network design from blocking the app rollout.

## API and runtime references

### Main hosted endpoints

Documented in the README and HTTP router:

- `GET /healthz`
- `GET /readyz`
- `GET /api/info`
- `GET /api/me`
- `GET/POST/PATCH/DELETE /api/accounts`
- `POST /api/accounts/:id/test`
- `GET /api/accounts/:id/mailboxes`
- `GET /api/accounts/:id/messages`
- `GET /api/accounts/:id/messages/:uid`
- `GET/POST/PATCH/DELETE /api/rules`
- `POST /api/rules/:id/dry-run`
- `/.well-known/oauth-protected-resource`
- `/mcp`

Evidence:

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/README.md:160-173`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/http.go:147-197`

### Runtime env/flag reference

The K3s deployment will need to drive these flags via environment variables:

```text
SMAILNAILD_LISTEN_HOST
SMAILNAILD_LISTEN_PORT
SMAILNAILD_DSN or SMAILNAILD_DATABASE
SMAILNAILD_ENCRYPTION_KEY_ID
SMAILNAILD_ENCRYPTION_KEY_BASE64
SMAILNAILD_AUTH_MODE
SMAILNAILD_AUTH_SESSION_COOKIE_NAME
SMAILNAILD_OIDC_ISSUER_URL
SMAILNAILD_OIDC_CLIENT_ID
SMAILNAILD_OIDC_CLIENT_SECRET
SMAILNAILD_OIDC_REDIRECT_URL
SMAILNAILD_OIDC_SCOPES
SMAILNAILD_MCP_ENABLED
SMAILNAILD_MCP_TRANSPORT
SMAILNAILD_MCP_AUTH_MODE
SMAILNAILD_MCP_AUTH_RESOURCE_URL
SMAILNAILD_MCP_OIDC_ISSUER_URL
SMAILNAILD_MCP_OIDC_AUDIENCE
SMAILNAILD_MCP_OIDC_REQUIRED_SCOPES
```

Evidence:

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/scripts/docker-entrypoint.smailnaild.sh:8-113`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/deployments/smailnaild-merged-coolify.md:69-124`

### Identity flow reference

```text
browser login:
  /auth/login
    -> Keycloak authorize endpoint
    -> /auth/callback
    -> verify id_token
    -> resolve local user by (issuer, subject)
    -> create web session

MCP call:
  bearer token at /mcp
    -> validate external OIDC token
    -> resolve same local user by (issuer, subject)
    -> load stored IMAP account owned by that user
    -> decrypt account credential with shared app key
```

Evidence:

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/shared-oidc-playbook.md:10-16`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/shared-oidc-playbook.md:115-169`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/auth/oidc.go:144-173`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/auth/oidc.go:175-319`

## Proposed implementation in detail

### 1. Source repo changes

Create these files in the `smailnail` repo:

1. `.github/workflows/publish-image.yaml`
2. `deploy/gitops-targets.json`
3. `scripts/open_gitops_pr.py`

Use `hair-booking` as the starting point:

- `/home/manuel/code/wesen/hair-booking/.github/workflows/publish-image.yaml:1-104`
- `/home/manuel/code/wesen/hair-booking/deploy/gitops-targets.json:1-11`
- `/home/manuel/code/wesen/hair-booking/scripts/open_gitops_pr.py:238-319`

The `smailnail` variant should:

- run `go test ./...`
- build and push `ghcr.io/<repo>:sha-<shortsha>`
- patch `gitops/kustomize/smailnail/deployment.yaml`
- open a GitOps PR against `wesen/2026-03-27--hetzner-k3s`

Suggested `deploy/gitops-targets.json` shape:

```json
{
  "targets": [
    {
      "name": "smailnail-prod",
      "gitops_repo": "wesen/2026-03-27--hetzner-k3s",
      "gitops_branch": "main",
      "manifest_path": "gitops/kustomize/smailnail/deployment.yaml",
      "container_name": "smailnail"
    }
  ]
}
```

### 2. Terraform and Keycloak changes

Add a parallel K3s-targeted Keycloak environment under the central Terraform repo. The exact path may be either:

- a new K3s-specific env under `apps/smailnail/envs/...`
- or an update to the hosted env if the repo treats K3s as the new hosted control plane

The important part is the values, not the directory name:

- browser client redirect URL should match the K3s app host
- browser web origin should match the K3s app host
- MCP client redirect URI allowance should include the K3s app host while retaining the Claude callback URIs
- issuer should align to the K3s Keycloak host, which this repo consistently treats as `auth.yolo.scapegoat.dev`

Suggested new values:

```text
realm: smailnail
browser client: smailnail-web
MCP client: smailnail-mcp
issuer: https://auth.yolo.scapegoat.dev/realms/smailnail
browser redirect: https://smailnail.yolo.scapegoat.dev/auth/callback
browser origin: https://smailnail.yolo.scapegoat.dev
MCP resource URL: https://smailnail.yolo.scapegoat.dev/mcp
```

This is aligned with the K3s Keycloak design:

- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0008--move-shared-keycloak-onto-k3s-under-argo-cd/design-doc/01-keycloak-on-k3s-implementation-design.md:34-40`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0008--move-shared-keycloak-onto-k3s-under-argo-cd/design-doc/01-keycloak-on-k3s-implementation-design.md:115-131`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0008--move-shared-keycloak-onto-k3s-under-argo-cd/design-doc/01-keycloak-on-k3s-implementation-design.md:153-176`

### 3. Vault secret model

I recommend one namespace-local runtime secret for the main app, sourced from Vault path:

```text
kv/apps/smailnail/prod/runtime
```

Suggested keys:

```text
dsn
database
username
password
encryption_key_id
encryption_key_base64
oidc_issuer_url
oidc_client_secret
oidc_redirect_url
mcp_auth_resource_url
mcp_oidc_issuer_url
mcp_oidc_audience
mcp_oidc_required_scopes
```

If the image package is private, also add:

```text
kv/apps/smailnail/prod/image-pull
```

The exact split can be:

- `runtime-secret.yaml` for app runtime values
- `image-pull-secret.yaml` only if GHCR pull auth is required

### 4. GitOps package in this repo

The `smailnail` package can be simpler than `draft-review` because the main app does not currently need media storage. If we use shared Postgres, the main package should contain roughly:

```text
gitops/kustomize/smailnail/
  namespace.yaml
  serviceaccount.yaml
  vault-connection.yaml
  vault-auth.yaml
  runtime-secret.yaml
  deployment.yaml
  service.yaml
  ingress.yaml
  kustomization.yaml

gitops/applications/smailnail.yaml
```

If Postgres database bootstrap is needed, also add:

```text
db-bootstrap-serviceaccount.yaml
db-bootstrap-vault-auth.yaml
postgres-admin-secret.yaml
db-bootstrap-script-configmap.yaml
db-bootstrap-job.yaml
```

Use the current `draft-review` package as the manifest reference:

- deployment/env wiring: `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/draft-review/deployment.yaml:21-101`
- runtime secret: `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/draft-review/runtime-secret.yaml:1-16`
- Argo app: `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/draft-review.yaml:1-23`

### 5. Shared Postgres bootstrap

If the app gets its own database and role in shared Postgres, use the documented bootstrap-job pattern instead of Terraform:

- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/vault-backed-postgres-bootstrap-job-pattern.md:27-42`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/vault-backed-postgres-bootstrap-job-pattern.md:169-219`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/vault-backed-postgres-bootstrap-job-pattern.md:221-267`

Reference implementation:

- job manifest: `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/draft-review/db-bootstrap-job.yaml:1-71`
- bootstrap script configmap: `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/draft-review/db-bootstrap-script-configmap.yaml:1-38`

Suggested `smailnail` values:

```text
database: smailnail
role: smailnail_app
namespace: smailnail
service account: smailnail
db bootstrap service account: smailnail-db-bootstrap
```

### 6. Deployment manifest shape

The main `Deployment` should set these env vars directly or via secret references:

```yaml
env:
  - name: SMAILNAILD_LISTEN_HOST
    value: 0.0.0.0
  - name: SMAILNAILD_LISTEN_PORT
    value: "8080"
  - name: SMAILNAILD_DSN
    valueFrom:
      secretKeyRef:
        name: smailnail-runtime
        key: dsn
  - name: SMAILNAILD_AUTH_MODE
    value: oidc
  - name: SMAILNAILD_OIDC_CLIENT_ID
    value: smailnail-web
  - name: SMAILNAILD_OIDC_ISSUER_URL
    valueFrom:
      secretKeyRef:
        name: smailnail-runtime
        key: oidc_issuer_url
  - name: SMAILNAILD_OIDC_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: smailnail-runtime
        key: oidc_client_secret
  - name: SMAILNAILD_OIDC_REDIRECT_URL
    valueFrom:
      secretKeyRef:
        name: smailnail-runtime
        key: oidc_redirect_url
  - name: SMAILNAILD_ENCRYPTION_KEY_ID
    valueFrom:
      secretKeyRef:
        name: smailnail-runtime
        key: encryption_key_id
  - name: SMAILNAILD_ENCRYPTION_KEY_BASE64
    valueFrom:
      secretKeyRef:
        name: smailnail-runtime
        key: encryption_key_base64
  - name: SMAILNAILD_MCP_ENABLED
    value: "1"
  - name: SMAILNAILD_MCP_TRANSPORT
    value: streamable_http
  - name: SMAILNAILD_MCP_AUTH_MODE
    value: external_oidc
  - name: SMAILNAILD_MCP_AUTH_RESOURCE_URL
    valueFrom:
      secretKeyRef:
        name: smailnail-runtime
        key: mcp_auth_resource_url
  - name: SMAILNAILD_MCP_OIDC_ISSUER_URL
    valueFrom:
      secretKeyRef:
        name: smailnail-runtime
        key: mcp_oidc_issuer_url
```

Use:

- `imagePullPolicy: IfNotPresent`
- readiness probe on `/readyz`
- liveness probe on `/healthz`
- service account only if it needs Vault/VSO or image-pull secret linkage

### 7. Service and ingress

Use a normal HTTP service and ingress, similar to the `draft-review` and `keycloak` app patterns:

```text
host: smailnail.yolo.scapegoat.dev
path prefix: /
TLS secret: smailnail-tls
cluster issuer: letsencrypt-prod
service port: 80 -> targetPort 8080
```

The important detail is that `/mcp` and `/.well-known/oauth-protected-resource` are just HTTP paths on the same host. They do not need their own service or separate ingress if the merged server remains the deployment target.

### 8. Argo CD application

Add:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: smailnail
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/wesen/2026-03-27--hetzner-k3s.git
    targetRevision: main
    path: gitops/kustomize/smailnail
  destination:
    server: https://kubernetes.default.svc
    namespace: smailnail
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

Then remember the one-time bootstrap step from the platform playbook:

```bash
kubectl apply -f gitops/applications/smailnail.yaml
kubectl -n argocd annotate application smailnail argocd.argoproj.io/refresh=hard --overwrite
```

Evidence:

- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/source-app-deployment-infrastructure-playbook.md:77-105`

### 9. Optional Dovecot fixture migration

If the requirement expands to "move the remote hosted IMAP fixture too," treat that as its own design item.

Why it is separate:

- it exposes raw TCP mail ports, not just HTTP
- it needs persistent Maildir state and TLS material
- normal Traefik ingress is not the right abstraction for IMAP/POP3/LMTP/ManageSieve

Possible shapes:

1. Keep the fixture on Coolify for now.
2. Move it to K3s with a dedicated raw TCP exposure strategy.
3. Replace it with a different test-infrastructure story entirely.

I recommend option 1 for the initial app migration unless the business requirement is explicitly to remove all Coolify workloads immediately.

## Pseudocode and flow sketches

### Release flow pseudocode

```text
on push to main:
  run go test ./...
  docker buildx build the root Dockerfile
  push ghcr.io/<repo>:sha-<shortsha>
  patch gitops/kustomize/smailnail/deployment.yaml image field
  open PR in wesen/2026-03-27--hetzner-k3s
```

### Runtime wiring pseudocode

```text
pod starts:
  load runtime secret
  connect to Postgres using DSN
  bootstrap schema if needed
  initialize OIDC settings
  mount HTTP routes:
    /healthz
    /readyz
    /auth/*
    /api/*
    /.well-known/oauth-protected-resource
    /mcp
    /
```

### Identity resolution diagram

```text
Browser
  -> /auth/login
  -> Keycloak
  -> /auth/callback
  -> smailnail user/session tables
  -> /api/accounts and /api/rules

MCP client
  -> /mcp with bearer token
  -> same Keycloak issuer
  -> same local user resolution
  -> stored IMAP account lookup by user_id
```

## Alternatives considered

### Alternative 1: Keep SQLite in K3s

This would minimize initial DB work and keep the runtime close to the current Coolify config.

Why I do not recommend it:

- it forces a PVC just to hold the app DB
- it couples app correctness to local filesystem state on the node
- it creates a migration later if the app ever needs better backup/restore or multi-pod behavior
- the platform already has shared Postgres and a proven bootstrap pattern

SQLite is acceptable as a fallback if the Postgres path blocks on external constraints, but it is not the better long-term K3s design.

### Alternative 2: Deploy the legacy standalone `smailnail-imap-mcp`

Why I do not recommend it:

- it reintroduces a split-brain deployment model
- it makes browser OIDC and stored-account MCP access harder to reason about
- the merged server is already the preferred production target

### Alternative 3: Move Dovecot in the same first slice

Why I do not recommend it:

- it mixes a normal HTTP app migration with a raw TCP mail service migration
- it adds networking complexity that is unrelated to the main app
- it creates more rollback surfaces for an intern’s first pass

## Phased implementation plan

### Phase 0: Confirm scope and hostnames

1. Confirm the final K3s app hostname.
2. Confirm whether GHCR package visibility should be public or private.
3. Confirm whether the Dovecot fixture is in or out of the first slice.

### Phase 1: Standardize the source repo release path

Files to add in `smailnail`:

- `.github/workflows/publish-image.yaml`
- `deploy/gitops-targets.json`
- `scripts/open_gitops_pr.py`
- `README.md` release-path section

Review focus:

- immutable image tags
- no direct deploy from source repo
- PR body includes source commit and workflow run

### Phase 2: Align Keycloak config with the K3s hostname model

Files to change in the Terraform repo:

- `keycloak/apps/smailnail/envs/hosted/main.tf` or a new K3s env alongside it
- possibly `terraform.tfvars.example`

Review focus:

- browser redirect/origin alignment
- MCP redirect URI and audience/scopes
- no accidental cutover of the external control plane before validation

### Phase 3: Add GitOps package in this repo

Files to add:

- `gitops/kustomize/smailnail/*`
- `gitops/applications/smailnail.yaml`

Review focus:

- secret references, not inline literals
- probes on `/readyz` and `/healthz`
- `imagePullPolicy: IfNotPresent`
- correct K3s hostnames

### Phase 4: Add DB bootstrap and Vault wiring

Files to add if Postgres is used:

- `db-bootstrap-script-configmap.yaml`
- `db-bootstrap-job.yaml`
- `postgres-admin-secret.yaml`
- `db-bootstrap-serviceaccount.yaml`
- `db-bootstrap-vault-auth.yaml`

Review focus:

- bootstrap job uses admin credential
- app deployment uses only runtime credential
- SQL is idempotent

### Phase 5: Validate end to end

1. Apply or bootstrap the Argo `Application`.
2. Wait for `Healthy`.
3. Verify `GET /readyz`.
4. Verify browser OIDC login.
5. Verify `GET /api/me`.
6. Create an IMAP account.
7. Create and dry-run a rule.
8. Call `/mcp` with a real access token and stored `accountId`.

### Phase 6: Cutover and cleanup

1. Decide whether to move external users from `smailnail.scapegoat.dev` to the K3s host.
2. Decide whether to retire the older standalone MCP path.
3. Decide whether the Dovecot fixture remains external or moves later.

## Testing and validation strategy

### Source repo validation

- `go test ./...`
- Docker build of the root `Dockerfile`
- workflow dry-run review on PR

### K3s validation

- Argo app `Synced` and `Healthy`
- deployment ready
- ingress resolves and TLS works
- runtime probes succeed

### Identity validation

- `/auth/login` redirects into the K3s Keycloak realm
- `/auth/callback` completes successfully
- `/api/me` returns the local user
- the same user can access `/mcp` via bearer token

### Data-path validation

- create IMAP account with `mcpEnabled: true`
- test account connectivity
- create rule
- run rule dry-run
- exercise MCP `executeIMAPJS` using the stored `accountId`

Suggested manual validation order:

```text
1. /readyz
2. /auth/login
3. /api/me
4. /api/accounts create
5. /api/accounts/:id/test
6. /api/rules create
7. /api/rules/:id/dry-run
8. /mcp with real OIDC token
```

## Risks, alternatives, and open questions

### Risk: stale hosted Keycloak client settings

The current hosted Terraform browser client still points at `smailnail.mcp.scapegoat.dev`, while the newer merged-host docs point at `smailnail.scapegoat.dev`. That suggests at least one of these is stale.

Mitigation:

- resolve this before copying values into the K3s env
- prefer live intent over historical accident

### Risk: raw-port Dovecot migration scope creep

If the Dovecot fixture gets bundled into the same first migration without a clear exposure model, it will likely consume time unrelated to the main app.

Mitigation:

- keep it as a separate explicit phase or separate ticket

### Risk: private GHCR image without cluster pull credentials

If the repo publishes privately and the GitOps package is merged before pull credentials exist, rollout will fail with image pull errors.

Mitigation:

- decide image visibility early
- if private, use the Vault-backed pull-secret pattern before rollout

### Risk: no PKCE in current browser OIDC flow

The OIDC doc explicitly says the current implementation uses confidential client secret flow and does not implement PKCE.

Evidence:

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/deployments/smailnaild-oidc-keycloak.md:19-24`

Mitigation:

- keep the confidential-client model for this migration
- do not try to redesign auth in the same slice

### Open questions

1. Should the K3s app host be `smailnail.yolo.scapegoat.dev`, or does a different subdomain need to be preserved?
2. Should the GHCR package be public, or should the cluster use a VSO-managed pull secret?
3. Is the old hosted browser-client redirect config stale, or does it reflect an unrecorded production routing detail?
4. Is moving the Dovecot fixture part of the same project or a later cleanup item?

## References

- `/home/manuel/code/wesen/corporate-headquarters/smailnail/README.md`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/Dockerfile`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/scripts/docker-entrypoint.smailnaild.sh`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/http.go`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/db.go`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/auth/config.go`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/auth/oidc.go`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/deployments/smailnaild-merged-coolify.md`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/deployments/smailnaild-oidc-keycloak.md`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/shared-oidc-playbook.md`
- `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/deployments/smailnail-dovecot-coolify.md`
- `/home/manuel/code/wesen/terraform/keycloak/apps/smailnail/envs/hosted/main.tf`
- `/home/manuel/code/wesen/hair-booking/.github/workflows/publish-image.yaml`
- `/home/manuel/code/wesen/hair-booking/deploy/gitops-targets.json`
- `/home/manuel/code/wesen/hair-booking/scripts/open_gitops_pr.py`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/source-app-deployment-infrastructure-playbook.md`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/vault-backed-postgres-bootstrap-job-pattern.md`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/draft-review/deployment.yaml`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/draft-review/runtime-secret.yaml`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/draft-review/db-bootstrap-job.yaml`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/draft-review/db-bootstrap-script-configmap.yaml`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/draft-review.yaml`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/deployment.yaml`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/keycloak-runtime-secret.yaml`
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/ingress.yaml`

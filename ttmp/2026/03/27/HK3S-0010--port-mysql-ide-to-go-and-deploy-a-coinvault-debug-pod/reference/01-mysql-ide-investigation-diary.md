---
Title: MySQL IDE investigation diary
Ticket: HK3S-0010
Status: active
Topics:
    - coinvault
    - k3s
    - mysql
    - gitops
    - debugging
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/internal/auth/config.go
      Note: Current app auth model inspected during Step 2
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/internal/sqltool/validate.go
      Note: Safe SQL groundwork inspected during Step 3
    - Path: ../../../../../../../2026-03-27--mysql-ide/imports/QueryMac.html
      Note: Prototype inspected during Step 1 investigation
    - Path: ../../../../../../../2026-03-27--mysql-ide/imports/proxy-server.js
      Note: Prototype proxy inspected during Step 1 investigation
    - Path: gitops/kustomize/coinvault/deployment.yaml
      Note: Live CoinVault contract inspected during Step 2
ExternalSources: []
Summary: Chronological investigation diary for the MySQL IDE port and CoinVault debug deployment implementation work.
LastUpdated: 2026-03-27T17:49:00-04:00
WhatFor: Capture the concrete prototype and deployment investigation trail behind HK3S-0010.
WhenToUse: Read this when continuing the ticket or reviewing why the design recommendations were chosen.
---


# MySQL IDE investigation diary

## Goal

Record the research and design synthesis for porting the MySQL IDE prototype to Go and deploying it as an authenticated CoinVault SQL debug workload on K3s.

## Step 1: inspect the prototype repo and identify what is actually there to port

The first thing I needed to answer was whether `/home/manuel/code/wesen/2026-03-27--mysql-ide` already contained a real application or just a visual sketch. The repo turned out to be extremely small: there is no Go code yet, no module, and no deployment packaging. The useful implementation surface is only two files:

- [`imports/QueryMac.html`](/home/manuel/code/wesen/2026-03-27--mysql-ide/imports/QueryMac.html)
- [`imports/proxy-server.js`](/home/manuel/code/wesen/2026-03-27--mysql-ide/imports/proxy-server.js)

That immediately changed the port framing. This is not a “translate a Node app to Go” task. It is a “preserve a frontend prototype and replace the entire backend/runtime contract” task.

### Prompt Context

**User prompt (verbatim):** "Create a new ticket to add a mysql IDE debug pod to the ocinvault deployment which also requires auth to test if the DB is correct, and configure it to be set against the coinvault SQL. 

For that, we are going to port a JS + html prototype to go + html. The tool is in /home/manuel/code/wesen/2026-03-27--mysql-ide . Create a detailed analysis and implementation plan for the port and deployment in the ticket. 

Create a detailed analysis / design / implementation guide that is very detailed for a new intern, explaining all the parts of the system needed to understand what it is, with prose paragraphs and bullet point sand pseudocode and diagrams and api references and file
  references.
  It should be very clear and detailed. Store in the ticket and the nupload to remarkable."

**Assistant interpretation:** Open a new HK3S ticket, inspect the prototype and current CoinVault runtime contract, then write a detailed design and implementation guide rather than implementing the port immediately.

**Inferred user intent:** Decide how the SQL debug tool should be built and deployed before touching code, and capture that decision trail as durable operator documentation.

### What I did
- Listed the prototype repo files.
- Read `QueryMac.html`.
- Read `proxy-server.js`.
- Identified the main UI behaviors and the current backend contract.

### Why
- The implementation plan depends heavily on whether the prototype is UI-only, backend-heavy, or already structured for reuse.

### What worked
- The prototype is self-contained enough to analyze quickly.
- The HTML already demonstrates the key UX features worth preserving.

### What didn't work
- There is no existing Go code, module, or deployable backend structure in the prototype repo. The port will have to establish all of that.

### What I learned
- The prototype already contains enough UI affordances to justify preserving the frontend shell.
- The Node proxy is too permissive and too generic for cluster deployment.

### What was tricky to build
- The tricky part was resisting the assumption that “port to Go” implies a full frontend rewrite too. The real risky work is backend/auth/safety, not HTML/CSS restyling.

### What warrants a second pair of eyes
- Review whether the first implementation should keep the current retro UI nearly intact or simplify it. My recommendation is to keep it intact for v1 so the port risk stays concentrated in the backend.

### What should be done in the future
- Inspect the live CoinVault runtime and auth contract next.

### Code review instructions
- Start with:
  - [`QueryMac.html`](/home/manuel/code/wesen/2026-03-27--mysql-ide/imports/QueryMac.html)
  - [`proxy-server.js`](/home/manuel/code/wesen/2026-03-27--mysql-ide/imports/proxy-server.js)

### Technical details
- The prototype frontend currently does all of these:
  - schema tree loading
  - freeform query execution
  - explain
  - formatting
  - CSV export
- The prototype backend currently:
  - accepts host/user/password/database from the browser
  - executes one statement with no semantic SQL validation
  - uses open CORS

## Step 2: inspect the live CoinVault deployment, auth model, and MySQL contract

After inspecting the prototype, I needed to understand what “add a debug pod to CoinVault” actually means in the live cluster. That meant reading the current CoinVault manifests and the existing app auth code rather than guessing from memory.

The live CoinVault deployment already gives us a stable contract:

- namespace: `coinvault`
- ingress host: `coinvault.yolo.scapegoat.dev`
- DB settings come from the VSO-synced `coinvault-runtime` secret
- MySQL points at `mysql.mysql.svc.cluster.local`
- the read-only application user is `coinvault_ro`
- browser auth is already OIDC-based through Keycloak

This was the most important result of the investigation because it means the debug tool should not invent a second database connection workflow. The cluster already knows which database the tool should talk to.

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Ground the ticket in the real CoinVault deployment and auth/runtime contract before deciding how the debug workload should look.

**Inferred user intent:** Avoid a generic prototype port that ignores how CoinVault actually runs on K3s.

### What I did
- Read:
  - [`gitops/kustomize/coinvault/deployment.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/deployment.yaml)
  - [`gitops/kustomize/coinvault/service.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/service.yaml)
  - [`gitops/kustomize/coinvault/ingress.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/ingress.yaml)
  - [`gitops/applications/mysql.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/mysql.yaml)
  - [`scripts/validate-cluster-mysql.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-cluster-mysql.sh)
  - CoinVault auth files:
    - [`config.go`](/home/manuel/code/gec/2026-03-16--gec-rag/internal/auth/config.go)
    - [`middleware.go`](/home/manuel/code/gec/2026-03-16--gec-rag/internal/auth/middleware.go)
    - [`server_bootstrap.go`](/home/manuel/code/gec/2026-03-16--gec-rag/internal/webchat/server_bootstrap.go)

### Why
- A design doc for this tool is only useful if it matches the current deployment and auth reality.

### What worked
- The CoinVault manifests and auth code are explicit enough that the intended runtime contract is clear.
- The current MySQL validation helper already proves the service name and user contract.

### What didn't work
- Nothing failed technically in this step. The main challenge was synthesizing app-repo and infra-repo responsibilities correctly.

### What I learned
- The right place for the debug tool is the `coinvault` namespace, but not necessarily inside the same pod.
- The tool should be authenticated using the same identity provider model, not basic auth or no auth.
- The tool should be fixed to CoinVault’s read-only DB contract, not browser-supplied credentials.

### What was tricky to build
- The tricky part was deciding whether “debug pod to the CoinVault deployment” should mean sidecar or sibling workload. After inspecting the manifests, sibling workload is the cleaner answer.

### What warrants a second pair of eyes
- Review whether the tool should reuse CoinVault’s OIDC client or get its own Keycloak client. My current recommendation is a dedicated client.

### What should be done in the future
- Inspect reusable safe SQL components next.

### Code review instructions
- Review the CoinVault deployment and auth files listed above and confirm the runtime contract described here matches the current manifests.

### Technical details
- Current CoinVault DB env keys:
  - `gec_mysql_host`
  - `gec_mysql_port`
  - `gec_mysql_database`
  - `gec_mysql_ro_user`
  - `gec_mysql_ro_password`
- Current MySQL service:
  - `mysql.mysql.svc.cluster.local:3306`

## Step 3: identify reuse opportunities and synthesize the recommended architecture

The last design question was safety. The prototype’s Node proxy is too permissive. But the CoinVault repo already contains a safe MySQL validator and schema-inspection logic under `internal/sqltool`. That meant I did not need to invent a security model from scratch; I needed to decide how to reuse or adapt it.

The key nuance is that the current validator is designed for safe model-generated SQL, not for a human IDE. It intentionally disallows `SHOW` statements and blocks `information_schema`, which is correct for user-generated app queries. For a SQL IDE, the right answer is not to loosen the query endpoint indiscriminately. The right answer is to split the API:

- server-owned schema endpoints may inspect metadata safely
- the user-authored query endpoint stays read-only and narrow

That is what led to the final recommendation:

- preserve the frontend shell
- replace the backend with Go
- deploy as a separate authenticated workload in namespace `coinvault`
- use fixed read-only DB config
- provide schema APIs plus validated user query execution

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Finish the research by choosing a concrete architecture and turning it into an intern-friendly design and implementation plan.

**Inferred user intent:** End this ticket creation pass with a clear recommendation, not just disconnected findings.

### What I did
- Read:
  - [`internal/sqltool/validate.go`](/home/manuel/code/gec/2026-03-16--gec-rag/internal/sqltool/validate.go)
  - [`internal/sqltool/types.go`](/home/manuel/code/gec/2026-03-16--gec-rag/internal/sqltool/types.go)
  - [`internal/sqltool/schema.go`](/home/manuel/code/gec/2026-03-16--gec-rag/internal/sqltool/schema.go)
- Compared those capabilities against the prototype’s current `SHOW DATABASES` / `SHOW TABLES` model.
- Wrote the design recommendation and implementation plan documents in this ticket.

### Why
- The main design risk was choosing between “generic SQL proxy” and “narrow operator tool.” The existing validator made the safer path obvious.

### What worked
- The existing CoinVault `sqltool` package gives a strong foundation for query validation.
- The prototype’s UI maps naturally onto a structured API model.

### What didn't work
- The existing validator cannot be used unchanged for the schema browser because it intentionally blocks exactly the metadata paths the UI wants.

### What I learned
- The right architecture is not “allow more SQL.” It is “move schema browsing into dedicated endpoints and keep user SQL narrow.”
- The port should be backend-heavy and security-heavy, not frontend-heavy.

### What was tricky to build
- The subtle part was balancing usefulness against safety. A human SQL IDE naturally tempts broader query support, but the whole point of this tool is to debug CoinVault safely, not to introduce a shadow admin console.

### What warrants a second pair of eyes
- Review the hostname and Keycloak-client recommendation.
- Review whether the implementation should copy the CoinVault auth package first or try to extract a shared package immediately.

### What should be done in the future
- Validate the ticket docs with `docmgr doctor`.
- Upload the ticket bundle to reMarkable.
- After that, open the real implementation pass in the `mysql-ide` repo and the K3s manifests.

### Code review instructions
- Review:
  - [`01-mysql-ide-port-and-coinvault-debug-deployment-design.md`](../design-doc/01-mysql-ide-port-and-coinvault-debug-deployment-design.md)
  - [`01-mysql-ide-implementation-and-deployment-plan.md`](../playbook/01-mysql-ide-implementation-and-deployment-plan.md)
- Confirm the design choices match the prototype findings and the live cluster contract.

### Technical details
- Current safe SQL foundation:
  - single-statement validation
  - read-only statement enforcement
  - row-limit normalization
  - schema inspection helpers

## Quick Reference

Recommended end-state in one paragraph:

```text
Build a small Go service in /home/manuel/code/wesen/2026-03-27--mysql-ide that embeds the current QueryMac-style HTML UI, uses OIDC auth, connects only to CoinVault’s read-only MySQL contract, exposes server-owned schema APIs plus a validated read-only query endpoint, and deploy it as a separate Deployment/Service/Ingress inside the existing CoinVault Argo package.
```

## Usage Examples

## Step 4: port the prototype into a real Go service and validate it locally

Once the design was clear, I switched from research to implementation in the app repo. The first goal was to build a complete service skeleton before touching the cluster. That meant bootstrapping the Go project structure, porting the auth model, replacing the Node proxy with a Go HTTP API, embedding the QueryMac-style UI, and building a read-only SQL safety boundary around schema browsing and ad hoc queries.

The important design choice here was to keep the prototype’s visual shell while rewriting the backend contract completely. That preserved operator familiarity and kept the implementation risk where it belonged: auth, DB safety, and deployment behavior.

### What I did
- Added the Go entrypoint and config loading:
  - [`main.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/cmd/mysql-ide/main.go)
  - [`config.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/app/config.go)
- Added local auth packages for `dev` and `oidc` modes:
  - [`config.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/auth/config.go)
  - [`middleware.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/auth/middleware.go)
  - [`oidc.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/auth/oidc.go)
  - [`session.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/auth/session.go)
- Added MySQL connection handling and the HTTP API:
  - [`mysql.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/db/mysql.go)
  - [`server.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/httpapi/server.go)
- Embedded the UI:
  - [`index.html`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/httpapi/static/index.html)
- Ported the SQL safety layer:
  - [`query.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/sqlguard/query.go)
  - [`validate.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/sqlguard/validate.go)
  - [`schema.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/sqlguard/schema.go)
- Added test coverage for auth config and SQL normalization.
- Added the app repo README:
  - [`README.md`](/home/manuel/code/wesen/2026-03-27--mysql-ide/README.md)

### What worked
- `go test ./...` passed.
- `go build ./cmd/mysql-ide` passed.
- `docker build -t mysql-ide:hk3s-0010 .` passed.
- The app is now documented well enough to run locally in `dev` mode without reading cluster manifests first.

### What was tricky
- The prototype was much looser than the cluster safety model, so the real work was mapping an open-ended SQL UI onto a much narrower server contract.
- The right answer was not to allow browser-provided DB credentials. The browser always talks to the server, and the server always uses the configured CoinVault DB contract.

### What should be reviewed
- Review the new README and confirm the env docs match the code in `internal/app` and `internal/auth`.

## Step 5: deploy the tool on K3s and reconcile the identity side safely

After the app repo was working locally, I moved to the cluster slice. The deployment work happened in the K3s repo, while the OIDC redirect coverage lived in the shared Terraform repo. The deployment shape stayed intentionally simple: one Deployment, one Service, one Ingress, all under the existing `coinvault` package.

The main operational risk in this step was identity drift. The Terraform repo root `.envrc` carries defaults for another realm, so a naive `terraform plan` would have targeted the wrong realm and produced a destructive-looking plan. The correct path was to override the CoinVault-specific variables explicitly before planning and applying.

### What I did
- Added:
  - [`mysql-ide-deployment.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml)
  - [`mysql-ide-service.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-service.yaml)
  - [`mysql-ide-ingress.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-ingress.yaml)
  - [`build-and-import-mysql-ide-image.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/build-and-import-mysql-ide-image.sh)
- Updated:
  - [`kustomization.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/kustomization.yaml)
- Reused the existing `coinvault-runtime` secret for:
  - DB host/port/name/user/password
  - OIDC client secret
  - session secret
- Extended Keycloak redirect coverage in:
  - [`main.tf`](/home/manuel/code/wesen/terraform/keycloak/apps/coinvault/envs/hosted/main.tf)
  - added `https://coinvault-sql.yolo.scapegoat.dev`

### What worked
- The manifests rendered and applied cleanly.
- The single-node image import path worked.
- The service came up publicly at `https://coinvault-sql.yolo.scapegoat.dev`.
- Anonymous users were redirected into Keycloak.

### What was tricky
- The root Terraform `.envrc` was hazardous in this repo context because it set another realm’s defaults.
- I had to extract the live `coinvault-web` client secret from the cluster secret to apply the Keycloak change safely.

### What should be reviewed
- Review the rollout playbook and make sure the Terraform override warning is prominent enough for the next operator.

## Step 6: run an authenticated smoke test, fix the schema bug, and write the operator handoff docs

The first fully authenticated browser smoke test surfaced a real runtime bug that would not have appeared in pure manifest review. The UI loaded, the login flow worked, but schema inspection failed with a metadata scan error. That proved the value of doing a real browser validation instead of stopping after `/healthz`.

The underlying issue was a mismatch between MySQL metadata column names and the `sqlx` scan target names in the schema layer. The fix was to alias the metadata query columns explicitly in [`schema.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/sqlguard/schema.go), rebuild the image, re-import it, and roll the Deployment.

### What I did
- Created a temporary Keycloak test user in the `coinvault` realm.
- Logged into the live service through the browser.
- Observed the initial failure:
  - `Startup error: scan schema table row: missing destination name TABLE_SCHEMA in *sqlguard.tableRow`
- Fixed the metadata aliasing bug in:
  - [`schema.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/sqlguard/schema.go)
- Rebuilt and re-imported the image.
- Restarted the Deployment.
- Re-ran the browser smoke test.
- Confirmed:
  - schema tree loads
  - `products` samples load
  - `DELETE FROM products` is rejected server-side
- Deleted the temporary Keycloak user after validation.
- Added:
  - [`README.md`](/home/manuel/code/wesen/2026-03-27--mysql-ide/README.md)
  - [`02-mysql-ide-rollout-and-rollback-playbook.md`](../playbook/02-mysql-ide-rollout-and-rollback-playbook.md)

### What worked
- The authenticated smoke test caught a real production-facing bug.
- The fix was contained to the app repo and did not require changing the deployment contract.
- The final state is operationally simple enough to document clearly.

### What was tricky
- The bug only showed up with real metadata returned by the live cluster MySQL server.
- The app repo currently has no configured Git remote, so the implementation can be committed locally but not pushed until a remote is added.

### What should be done next
- Push the K3s repo and Terraform repo closeout commits.
- Re-check Argo convergence from pushed Git state.
- Refresh the reMarkable ticket bundle after the final docs are committed.

## Step 7: validate the final GitOps state and capture the remaining repo boundary

After the rollout and documentation work were in place, I ran the closeout checks that matter for long-term maintainability. The core question was no longer “does the pod run?” It was “is the deployment now converged from Git, and does the ticket explain the remaining operational caveats clearly enough that the next person will not repeat the same mistakes?”

### What I did
- Re-ran:
  - `go test ./...` in `/home/manuel/code/wesen/2026-03-27--mysql-ide`
  - `docmgr doctor --ticket HK3S-0010 --stale-after 30`
- Verified Argo convergence with the real kubeconfig:
  - `kubectl -n argocd get application coinvault ...`
- Verified the live public contract again:
  - `curl -ksS https://coinvault-sql.yolo.scapegoat.dev/healthz`
- Confirmed the app repo still has no configured Git remote.
- Committed:
  - the app repo README locally
  - the Terraform Keycloak callback change
- Prepared the K3s repo closeout commit with manifests, script, and ticket docs.

### What worked
- Argo reported `Synced Healthy`.
- The public `healthz` response matched the intended DB/auth contract.
- The ticket passes `docmgr doctor`.

### What is still important to remember
- The app repo implementation is committed locally, but it cannot be pushed until a Git remote is configured for `/home/manuel/code/wesen/2026-03-27--mysql-ide`.
- The K3s and Terraform repos do not have that problem and can be pushed normally.

Use this diary when:

- continuing the ticket after a pause
- explaining why the tool should not accept arbitrary browser DB credentials
- explaining why this should be a separate deployment rather than a sidecar
- explaining why schema browsing and user-authored SQL should be separate API surfaces

## Related

- [01-mysql-ide-port-and-coinvault-debug-deployment-design.md](../design-doc/01-mysql-ide-port-and-coinvault-debug-deployment-design.md)
- [01-mysql-ide-implementation-and-deployment-plan.md](../playbook/01-mysql-ide-implementation-and-deployment-plan.md)
- [HK3S-0007](../../HK3S-0007--recreate-the-first-application-on-k3s-using-vault-managed-secrets/index.md)
- [HK3S-0009](../../HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/index.md)

## Step 4: turn the design into a real Go service in the mysql-ide repo

The implementation pass started by converting the design ticket into a real execution ticket and then scaffolding the new app repo from scratch. The repo had no Go module, no Dockerfile, and no runtime structure, so the first goal was to create a service that compiled cleanly and carried the same architectural boundary the design recommended: embedded UI, fixed CoinVault DB contract, and `dev|oidc` auth.

I deliberately did not copy the entire CoinVault app server or bootstrap machinery. Instead, I built a smaller purpose-specific service in `/home/manuel/code/wesen/2026-03-27--mysql-ide` that ports only the needed pieces: an auth/session layer, a read-only SQL guard, schema inspection helpers, a JSON HTTP API, and a QueryMac-style frontend that now talks to those server endpoints rather than a browser-owned DB proxy.

### Prompt Context

**User prompt (verbatim):** "Add detailed tasks to the ticket, and then work on it. Use the remote git repo for the implementation work, but I think everything deployment is going to be in this gitops repo."

**Assistant interpretation:** Expand the ticket task list into a real execution plan, then begin implementation in the separate `mysql-ide` application repo while keeping deployment wiring in the K3s GitOps repo.

**Inferred user intent:** Move HK3S-0010 out of the design-only phase and into a real, staged implementation with durable diary entries and Git checkpoints.

**Commit (code):** `e78349e` — `feat: add mysql ide go service scaffold`

### What I did
- Expanded `tasks.md` into granular execution phases.
- Initialized the Go module in `/home/manuel/code/wesen/2026-03-27--mysql-ide`.
- Added:
  - `cmd/mysql-ide/main.go`
  - `internal/app/config.go`
  - `internal/auth/*`
  - `internal/db/mysql.go`
  - `internal/safesqlcore/*`
  - `internal/sqlguard/*`
  - `internal/httpapi/server.go`
  - `internal/httpapi/static/index.html`
  - `Dockerfile`
- Added focused tests for auth config and SQL normalization/validation.
- Verified:
  - `go test ./...`
  - `go build ./cmd/mysql-ide`

### Why
- The prototype had no backend worth preserving.
- The fastest safe route was a purpose-built Go service rather than trying to force the existing Node proxy into cluster deployment.

### What worked
- The TiDB parser-based SQL guard ported cleanly.
- A smaller self-contained auth package was enough to preserve the `dev|oidc` behavior shape without coupling directly to CoinVault internals.
- The QueryMac shell adapted well to a fixed-cluster-mode API.

### What didn't work
- `go build ./cmd/mysql-ide` wrote a local `mysql-ide` binary into the repo root, which needed repo hygiene handling.
- The initial Dockerfile used `golang:1.24-bookworm`, but `go mod tidy` had upgraded the module to `go 1.25.5`, so the first Docker build failed with:
  - `go.mod requires go >= 1.25.5 (running go 1.24.13; GOTOOLCHAIN=local)`

### What I learned
- For this repo, a greenfield service was faster and cleaner than trying to preserve the original backend contract.
- The embedded frontend can stay close to the prototype while the real complexity lives in auth, DB safety, and deployment.

### What was tricky to build
- The sharp edge here was dependency scope. It would have been easy to over-copy large parts of CoinVault. The better boundary was to port only the minimum auth/session and SQL-safety pieces required for this tool.

### What warrants a second pair of eyes
- Review the OIDC callback/logout behavior, especially because it is a smaller local reimplementation of the CoinVault pattern rather than a shared extracted package.
- Review the SQL guard for any gaps between the prototype affordances and the now-enforced read-only semantics.

### What should be done in the future
- Wire the service into K3s next.
- Add a short env-var contract doc in the app repo.

### Code review instructions
- Start with:
  - [`main.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/cmd/mysql-ide/main.go)
  - [`server.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/httpapi/server.go)
  - [`index.html`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/httpapi/static/index.html)
  - [`validate.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/sqlguard/validate.go)
- Validate with:
  - `go test ./...`
  - `go build ./cmd/mysql-ide`
  - `docker build -t mysql-ide:hk3s-0010 .`

### Technical details
- Runtime contract uses:
  - `MYSQL_IDE_DB_*`
  - `MYSQL_IDE_AUTH_*`
  - `MYSQL_IDE_OIDC_*`
- The browser no longer supplies host/user/password/database.
- The frontend now uses:
  - `GET /healthz`
  - `GET /api/me`
  - `GET /api/schema`
  - `GET /api/schema/table/{name}/sample`
  - `POST /api/query`

## Step 5: wire the service into GitOps and Keycloak, then deploy it live

Once the app compiled locally, the deployment slice broke into three concrete pieces: image import, GitOps manifests, and Keycloak redirect coverage. The GitOps package was straightforward: add a sibling deployment/service/ingress in `gitops/kustomize/coinvault`, point it at the same `coinvault-runtime` secret for the DB contract and OIDC client secret, and use the wildcard host `coinvault-sql.yolo.scapegoat.dev`.

The more important discovery was operational rather than code-related. The shared Terraform repo’s root `.envrc` exports `TF_VAR_realm_name=smailnail`, which would have been disastrous if I had applied the Keycloak change blindly in the CoinVault env. The first `terraform plan` caught this because it tried to replace the `coinvault` realm with `smailnail`. I corrected that by explicitly overriding `TF_VAR_realm_name=coinvault`, `TF_VAR_realm_display_name=coinvault`, `TF_VAR_public_app_url=https://coinvault.app.scapegoat.dev`, and `TF_VAR_web_client_secret=<live coinvault client secret from cluster secret>` before applying.

### Prompt Context

**User prompt (verbatim):** (same as Step 4)

**Assistant interpretation:** Continue the implementation into the live deployment slice, using the app repo for code and the K3s GitOps repo for cluster manifests.

**Inferred user intent:** Do not stop at local scaffolding; carry the feature through image build, auth wiring, and a real cluster rollout.

### What I did
- Added K3s manifests:
  - [`mysql-ide-deployment.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml)
  - [`mysql-ide-service.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-service.yaml)
  - [`mysql-ide-ingress.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-ingress.yaml)
  - updated [`kustomization.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/kustomization.yaml)
- Added the image helper:
  - [`build-and-import-mysql-ide-image.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/build-and-import-mysql-ide-image.sh)
- Updated Keycloak client redirects in:
  - [`main.tf`](/home/manuel/code/wesen/terraform/keycloak/apps/coinvault/envs/hosted/main.tf)
- Built and imported the image to the Hetzner node.
- Applied the manifests to the cluster.
- Confirmed:
  - pod `mysql-ide` running
  - ingress `coinvault-sql.yolo.scapegoat.dev`
  - `curl -ksS https://coinvault-sql.yolo.scapegoat.dev/healthz`
  - `curl -ksSI https://coinvault-sql.yolo.scapegoat.dev/`

### Why
- The design only becomes useful once the service can be exercised against the live CoinVault schema on the cluster.
- Reusing the existing `coinvault-web` Keycloak client was the fastest safe auth path for the first deployment slice.

### What worked
- `kubectl kustomize gitops/kustomize/coinvault` rendered cleanly.
- Terraform updated the `coinvault-web` client in-place once the env vars were overridden correctly.
- The image imported cleanly to the K3s node and the deployment came up as `1/1 Running`.
- Anonymous behavior worked immediately:
  - `/healthz` returned the expected fixed DB contract
  - `/api/me` returned anonymous state
  - `/` redirected to `/auth/login?return_to=%2F`

### What didn't work
- The first Terraform plan sourced from the repo root `.envrc` tried to replace the `coinvault` realm with `smailnail`.
- That plan output showed:
  - `realm = "coinvault" -> "smailnail" # forces replacement`
- This was not applied; it was corrected before the real apply.

### What I learned
- The shared Terraform repo must not be trusted to carry the correct env defaults for each app environment.
- For this feature, reusing `coinvault-runtime` for DB + OIDC client secret is enough to get the first deployment live.

### What was tricky to build
- The sharp edge was configuration scoping, not YAML authoring. The manifests themselves were straightforward; the dangerous part was making sure the live Keycloak apply targeted the CoinVault realm rather than inheriting unrelated repo-root defaults.

### What warrants a second pair of eyes
- Review whether continuing to reuse `coinvault-runtime` for the IDE is acceptable long term, or whether a dedicated `mysql-ide-runtime` path should be created in Vault.
- Review whether the debug workload should keep sharing the `coinvault-web` client or eventually move to its own Keycloak client.

### What should be done in the future
- Validate the app through a real authenticated browser session.
- Commit and push the GitOps + Terraform repo changes so Argo is reconciled from Git rather than only via manual `kubectl apply`.

### Code review instructions
- Review the new manifests and the Keycloak env change:
  - [`mysql-ide-deployment.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml)
  - [`mysql-ide-service.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-service.yaml)
  - [`mysql-ide-ingress.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-ingress.yaml)
  - [`main.tf`](/home/manuel/code/wesen/terraform/keycloak/apps/coinvault/envs/hosted/main.tf)
- Validate with:
  - `kubectl kustomize gitops/kustomize/coinvault`
  - `K3S_NODE_HOST=91.98.46.169 ./scripts/build-and-import-mysql-ide-image.sh`
  - `kubectl -n coinvault get deploy,svc,ingress,pods`
  - `curl -ksS https://coinvault-sql.yolo.scapegoat.dev/healthz`

### Technical details
- Live host:
  - `coinvault-sql.yolo.scapegoat.dev`
- Reused cluster secret:
  - `coinvault-runtime`
- Reused Keycloak client:
  - `coinvault-web`

## Step 6: run an authenticated smoke test, find the live schema bug, and fix it

The anonymous checks proved the ingress and auth boundary, but they did not prove the actual operator workflow. To test the full path without using a personal account, I created a disposable user in the `coinvault` realm through the Keycloak admin API, signed in through the live hosted UI with Playwright, exercised the schema browser and sample-table path, and then deleted that user after validation.

That authenticated smoke test found the first real live bug in the port: schema loading failed with `missing destination name TABLE_SCHEMA in *sqlguard.tableRow`. The app was healthy and the OIDC flow was correct, but `sqlx` was scanning MySQL metadata rows using uppercase driver column names while the struct tags expected lowercase names. I fixed that by adding explicit aliases in the schema queries, rebuilt the image, re-imported it to the node, restarted the deployment, and reran the live authenticated check.

### Prompt Context

**User prompt (verbatim):** (same as Step 4)

**Assistant interpretation:** Carry the implementation through real operator validation rather than stopping at “pod is running”.

**Inferred user intent:** The tool should work for the actual CoinVault debugging use case, not just compile and expose an ingress.

**Commit (code):** `ab7bc35` — `fix: normalize schema metadata aliases`

### What I did
- Created a disposable Keycloak `coinvault` realm user for smoke validation.
- Used Playwright to:
  - open `https://coinvault-sql.yolo.scapegoat.dev`
  - complete OIDC login
  - verify the authenticated UI loaded
  - inspect the schema tree
  - sample the `products` table
  - run an unsafe query and verify rejection
- Fixed the schema metadata scan bug in:
  - [`schema.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/sqlguard/schema.go)
- Rebuilt/imported the image and rolled the deployment.
- Deleted the disposable Keycloak user after the smoke test.

### Why
- Anonymous checks are not enough for an auth-protected debug tool.
- The schema tree is a core operator flow, so it had to be proven live.

### What worked
- OIDC login succeeded end to end.
- After the fix, the authenticated UI loaded the `gec` schema table list.
- Sampling `products` returned live data from the CoinVault DB.
- Unsafe SQL rejection worked live:
  - `SQL Error: statement type *ast.DeleteStmt is not allowed`

### What didn't work
- Before the fix, the UI showed:
  - `Startup error: scan schema table row: missing destination name TABLE_SCHEMA in *sqlguard.tableRow`
- The browser also reported `404` for `/favicon.ico`, which is cosmetic and not functionally important.

### What I learned
- The highest-value validation steps are browser-authenticated operator flows, not just `curl` health checks.
- MySQL metadata scanning needs explicit aliases for stable `sqlx` field mapping in this code path.

### What was tricky to build
- The difficult part was not auth itself; it was proving the authenticated path without relying on an operator’s personal session. The disposable realm user plus Playwright flow was the cleanest way to validate and then clean up afterward.

### What warrants a second pair of eyes
- Review whether the sample-table endpoint should expose narrower default projections for very wide tables.
- Review whether the UI should surface query truncation more explicitly for large result sets.

### What should be done in the future
- Commit/push the GitOps and Terraform repo changes so Argo can reconcile from Git.
- Add operator playbook details and rollback notes.

### Code review instructions
- Review:
  - [`schema.go`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/sqlguard/schema.go)
  - [`index.html`](/home/manuel/code/wesen/2026-03-27--mysql-ide/internal/httpapi/static/index.html)
  - [`mysql-ide-deployment.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml)
- Validate with:
  - `curl -ksS https://coinvault-sql.yolo.scapegoat.dev/healthz`
  - anonymous `curl -ksSI https://coinvault-sql.yolo.scapegoat.dev/`
  - authenticated browser login and schema browse

### Technical details
- Live smoke results after the fix:
  - root path redirects to Keycloak when anonymous
  - schema tree lists `gec` tables
  - sample `products` read succeeds
  - `DELETE FROM products` is rejected at the API boundary

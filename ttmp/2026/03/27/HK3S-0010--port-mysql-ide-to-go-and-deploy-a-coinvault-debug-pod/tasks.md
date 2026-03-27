# Tasks

## Phase 1: Analyze the prototype and the live CoinVault contract

- [x] Inspect the `QueryMac.html` prototype and the `proxy-server.js` backend contract
- [x] Inspect the live CoinVault K3s deployment, ingress, and runtime secret contract
- [x] Inspect the current CoinVault auth and safe-SQL code paths for reuse opportunities
- [x] Document the recommended architecture and porting strategy

## Phase 2: Port the prototype to a Go service in `/home/manuel/code/wesen/2026-03-27--mysql-ide`

- [x] Initialize the Go module and repo layout:
  - `cmd/mysql-ide`
  - `internal/app`
  - `internal/auth`
  - `internal/db`
  - `internal/httpapi`
  - `internal/sqlguard`
  - `web/`
- [x] Add a working `main.go` bootstrap that loads config, constructs the server, and starts HTTP listening
- [x] Preserve the current HTML/CSS/vanilla-JS UI shell as the first frontend pass
- [x] Split the prototype into embedded assets under `web/`
- [x] Replace the Node proxy with a Go HTTP server
- [x] Add embedded static asset serving through `go:embed`
- [x] Add JSON helpers and error response conventions for API routes
- [x] Add health and auth/user info endpoints
- [ ] Add unit tests for config parsing and core handler behavior

## Phase 3: Add auth and runtime configuration

- [x] Port the minimal CoinVault OIDC/session pattern into the new repo as a local package
- [x] Add `dev` and `oidc` auth modes so local development is still possible without Keycloak
- [x] Add OIDC-protected browser login, callback, logout, and logout-callback handlers
- [x] Add middleware that protects the UI and API routes but leaves `healthz` reachable
- [x] Add an IDE-specific session cookie name and public URL settings
- [x] Decide the public hostname and Keycloak client model
- [x] Decide the runtime secret contract:
  - DB host/port/schema/user/password
  - OIDC issuer/client ID/client secret
  - session secret
- [x] Decide whether to reuse `coinvault-runtime` fields or add a dedicated IDE secret path in Vault
- [x] Add local documentation for all required env vars and their intended secret source

## Phase 4: Implement the DB and query API

- [x] Add fixed server-side DB configuration using the CoinVault MySQL contract instead of browser-supplied credentials
- [x] Add a connection layer with pooled MySQL access
- [x] Port or adapt the safe read-only SQL validator from CoinVault
- [x] Add a validated query execution endpoint with:
  - single-statement enforcement
  - timeout
  - row cap
  - query metadata in the response
- [x] Add schema endpoints for:
  - database summary
  - table list
  - table details
  - sample rows
- [x] Ensure schema endpoints use server-owned SQL instead of raw browser `SHOW` statements
- [x] Add tests for read-only acceptance and write/unsafe rejection

## Phase 5: Wire the frontend to the new API

- [x] Replace the prototype connection dialog with fixed-cluster-mode semantics
- [x] Update the schema tree to call the new schema endpoints
- [x] Update query execution to call the validated `POST /api/query` endpoint
- [x] Add login/logout/current-user UI state
- [x] Keep the existing visual shell while removing assumptions about browser-owned DB credentials
- [x] Verify the UI still supports the operator flows:
  - schema browse
  - sample rows
  - ad hoc read-only query
  - clear results
  - export CSV

## Phase 6: Containerize and validate the app repo locally

- [x] Add a Dockerfile for the Go service
- [x] Add local run instructions for `dev` auth mode
- [x] Add local integration instructions for pointing at MySQL safely
- [x] Run `go test ./...`
- [x] Build the image locally
- [ ] Smoke-test the HTTP server and the embedded UI locally

## Phase 7: Deploy the tool on K3s

- [x] Add Kubernetes manifests for the IDE to the CoinVault GitOps package
- [x] Add Deployment, Service, and Ingress objects
- [x] Add any needed ConfigMap and Secret references
- [x] Wire the pod to the CoinVault MySQL read-only contract
- [x] Confirm that no additional VSO secret sync objects are needed because the deployment reuses the existing `coinvault-runtime` secret
- [x] Add sync-wave annotations only where dependency ordering actually requires them
- [x] Validate the Argo CD rollout from pushed Git after the final closeout commits land

## Phase 8: Validate operator behavior

- [x] Prove that browser auth is required
- [x] Prove the tool reaches the correct cluster MySQL service and schema
- [x] Prove safe schema browsing works
- [x] Prove read-only SQL execution works
- [x] Prove write/unsafe statements are rejected
- [x] Prove the tool cannot switch to arbitrary external DB credentials in cluster mode
- [x] Prove the UI is actually pointed at the CoinVault schema/data operators expect
- [x] Record the operator playbook and rollback boundaries

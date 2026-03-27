# Tasks

## Phase 1: Analyze the prototype and the live CoinVault contract

- [x] Inspect the `QueryMac.html` prototype and the `proxy-server.js` backend contract
- [x] Inspect the live CoinVault K3s deployment, ingress, and runtime secret contract
- [x] Inspect the current CoinVault auth and safe-SQL code paths for reuse opportunities
- [x] Document the recommended architecture and porting strategy

## Phase 2: Port the prototype to a Go service in `/home/manuel/code/wesen/2026-03-27--mysql-ide`

- [ ] Initialize the Go module and basic repo structure
- [ ] Preserve the current HTML/CSS/vanilla-JS UI shell as the first frontend pass
- [ ] Replace the Node proxy with a Go HTTP server
- [ ] Add embedded static asset serving through `go:embed`
- [ ] Add MySQL connectivity using fixed server-side config instead of browser-supplied credentials
- [ ] Add safe SQL validation and execution paths
- [ ] Add dedicated schema endpoints for tree browsing instead of raw `SHOW DATABASES` from the browser
- [ ] Add health and auth/user info endpoints

## Phase 3: Add auth and runtime configuration

- [ ] Decide whether to copy or extract the CoinVault OIDC/session pattern into the new repo
- [ ] Add OIDC-protected browser login to the IDE
- [ ] Add an IDE-specific runtime secret path or reuse the existing CoinVault runtime secret selectively
- [ ] Decide the public hostname and Keycloak client model

## Phase 4: Deploy the tool on K3s

- [ ] Add Kubernetes manifests for the IDE to the CoinVault GitOps package
- [ ] Add Deployment, Service, and Ingress objects
- [ ] Wire the pod to the CoinVault MySQL read-only contract
- [ ] Add any needed VSO secret sync objects
- [ ] Validate the Argo CD rollout

## Phase 5: Validate operator behavior

- [ ] Prove that browser auth is required
- [ ] Prove the tool reaches the correct cluster MySQL service and schema
- [ ] Prove safe schema browsing works
- [ ] Prove read-only SQL execution works
- [ ] Prove write/unsafe statements are rejected
- [ ] Record the operator playbook and rollback boundaries

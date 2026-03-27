---
Title: MySQL IDE implementation and deployment plan
Ticket: HK3S-0010
Status: active
Topics:
    - coinvault
    - k3s
    - mysql
    - gitops
    - debugging
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/internal/auth/middleware.go
      Note: Reference OIDC/session middleware flow for the new app
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/internal/sqltool/schema.go
      Note: Reference schema inspection helpers for server-owned metadata endpoints
    - Path: gitops/kustomize/coinvault/kustomization.yaml
      Note: Target GitOps package that should gain the debug workload manifests
    - Path: scripts/validate-cluster-mysql.sh
      Note: Current cluster MySQL validation procedure to mirror in deployment testing
ExternalSources: []
Summary: Step-by-step implementation plan for porting the MySQL IDE to Go and deploying it with CoinVault on K3s.
LastUpdated: 2026-03-27T17:24:00-04:00
WhatFor: Provide the concrete step-by-step execution plan for porting the MySQL IDE and deploying it with CoinVault.
WhenToUse: Use this when implementing HK3S-0010 after the design is approved.
---


# MySQL IDE implementation and deployment plan

## Purpose

This playbook turns the design into an execution sequence. It is written for the future implementation pass, not because every command should be run right now. The goal is to make the port and deployment order obvious enough that an intern can follow it without improvising the architecture mid-flight.

## Environment Assumptions

- K3s repo:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s`
- prototype/new app repo:
  - `/home/manuel/code/wesen/2026-03-27--mysql-ide`
- CoinVault app repo for reference only:
  - `/home/manuel/code/gec/2026-03-16--gec-rag`
- working kubeconfig for the live cluster
- CoinVault and MySQL Argo apps already healthy
- Vault/VSO path already available in namespace `coinvault`
- access to the shared Terraform repo if a new Keycloak client is created

Important assumption:

- the IDE is a debug/operator tool for the CoinVault database, not a general-purpose multi-DB admin panel

## Commands

### Phase 1: scaffold the Go app in the mysql-ide repo

```bash
cd /home/manuel/code/wesen/2026-03-27--mysql-ide
git status --short
```

Recommended initial structure:

```text
cmd/mysql-ide/main.go
internal/server/
internal/auth/
internal/db/
internal/sqlguard/
web/
```

Recommended first commands:

```bash
go mod init github.com/wesen/2026-03-27--mysql-ide
mkdir -p cmd/mysql-ide internal/server internal/auth internal/db internal/sqlguard web/static
```

### Phase 2: move the prototype UI into embedded assets

Copy/adapt:

- `/home/manuel/code/wesen/2026-03-27--mysql-ide/imports/QueryMac.html`

Target idea:

- split into `web/index.html`
- optionally factor CSS/JS into `web/static/`
- serve via `go:embed`

### Phase 3: implement the Go server

Core endpoints to implement:

```text
GET  /healthz
GET  /api/me
GET  /api/schema
GET  /api/schema/table/{name}
GET  /api/schema/table/{name}/sample
POST /api/query
GET  /auth/login
GET  /auth/callback
GET  /auth/logout
GET  /auth/logout/callback
```

Suggested local run loop:

```bash
go test ./... -count=1
go run ./cmd/mysql-ide
```

### Phase 4: port auth carefully

Reference files:

- `/home/manuel/code/gec/2026-03-16--gec-rag/internal/auth/config.go`
- `/home/manuel/code/gec/2026-03-16--gec-rag/internal/auth/middleware.go`
- `/home/manuel/code/gec/2026-03-16--gec-rag/internal/auth/oidc.go`

Recommended implementation order:

1. port session manager and OIDC callback flow
2. add root-path/public-url settings
3. protect UI and API routes
4. leave `/healthz` public

### Phase 5: implement server-owned DB and schema APIs

Reference files:

- `/home/manuel/code/gec/2026-03-16--gec-rag/internal/sqltool/schema.go`
- `/home/manuel/code/gec/2026-03-16--gec-rag/internal/sqltool/validate.go`

Suggested rules:

- schema inspection routes are generated server-side
- query route validates user SQL
- user SQL does not get direct `SHOW` or arbitrary schema switching
- responses include clear query/error metadata

### Phase 6: containerize and run locally

After the app works locally:

```bash
docker build -t mysql-ide:dev .
docker run --rm -p 8080:8080 mysql-ide:dev
```

### Phase 7: wire the K3s manifests

In `/home/manuel/code/wesen/2026-03-27--hetzner-k3s`, add:

- deployment manifest
- service manifest
- ingress manifest
- optional VSO secret manifest for IDE-specific auth secrets

Then update:

- `gitops/kustomize/coinvault/kustomization.yaml`

### Phase 8: deploy and validate

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml
kubectl kustomize gitops/kustomize/coinvault
kubectl -n argocd get application coinvault
kubectl -n coinvault get deploy,svc,ingress
kubectl -n coinvault logs deploy/<mysql-ide-deployment-name> --tail=200
```

Then validate in browser:

- login required
- schema tree loads
- sample query works
- write query rejected
- only the CoinVault DB is reachable

## Exit Criteria

The ticket implementation is only complete when all of the following are true:

- `/home/manuel/code/wesen/2026-03-27--mysql-ide` contains a working Go service
- the service serves the QueryMac-style UI
- auth is required in cluster mode
- the deployment is part of the CoinVault GitOps package
- the service connects to the fixed CoinVault MySQL contract
- schema browsing works without raw `SHOW DATABASES` from the browser
- unsafe statements are rejected clearly
- the Argo app stays `Synced Healthy`

## Notes

- Do not preserve the prototype’s arbitrary browser-supplied DB credentials in cluster mode.
- Do not expose this tool without auth.
- Do not rely only on the read-only DB user; keep server-side query validation too.
- Prefer keeping the first frontend pass close to the current prototype so that the risky work stays concentrated in backend/auth/deployment logic.

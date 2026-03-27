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
Summary: Chronological investigation diary for the MySQL IDE port and CoinVault debug deployment design work.
LastUpdated: 2026-03-27T17:24:00-04:00
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

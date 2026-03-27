---
Title: Port MySQL IDE to Go and deploy a CoinVault debug pod
Ticket: HK3S-0010
Status: active
Topics:
    - coinvault
    - k3s
    - mysql
    - gitops
    - debugging
DocType: index
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: "Implementation ticket for porting the MySQL IDE prototype to Go and deploying it as an authenticated CoinVault SQL debug workload on K3s."
LastUpdated: 2026-03-27T17:49:00-04:00
WhatFor: "Use this ticket to implement, operate, and review the Go port of the MySQL IDE prototype plus the GitOps deployment of an authenticated CoinVault SQL debug tool against the cluster MySQL service."
WhenToUse: "Read this when implementing, operating, or reviewing the browser-based SQL debug tool for CoinVault on K3s."
---

# Port MySQL IDE to Go and deploy a CoinVault debug pod

## Overview

This ticket covers two linked pieces of work:

- port the existing prototype in `/home/manuel/code/wesen/2026-03-27--mysql-ide` from `HTML + Node proxy` into a real `Go + HTML` application
- deploy that application as an authenticated debug workload alongside CoinVault on the K3s cluster, wired to the same CoinVault MySQL database contract

The main point is not to create a generic database admin tool. The point is to create a tightly scoped operator/debug surface for the CoinVault data path so that a human can inspect schema and run safe read-only queries when the app or import path looks wrong.

## Current Step

Step 6 is active: the implementation is deployed and validated, and the final closeout work is publishing the Git history and refreshed ticket bundle while recording the remaining app-repo remote gap.

## Key Links

- Design doc:
  - [01-mysql-ide-port-and-coinvault-debug-deployment-design.md](./design-doc/01-mysql-ide-port-and-coinvault-debug-deployment-design.md)
- Implementation playbook:
  - [01-mysql-ide-implementation-and-deployment-plan.md](./playbook/01-mysql-ide-implementation-and-deployment-plan.md)
- Investigation diary:
  - [01-mysql-ide-investigation-diary.md](./reference/01-mysql-ide-investigation-diary.md)
- Rollout and rollback playbook:
  - [02-mysql-ide-rollout-and-rollback-playbook.md](./playbook/02-mysql-ide-rollout-and-rollback-playbook.md)
- Related migration tickets:
  - [HK3S-0007](../HK3S-0007--recreate-the-first-application-on-k3s-using-vault-managed-secrets/index.md)
  - [HK3S-0009](../HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/index.md)

## Status

Current status: **active**

Current recommendation:

- keep the current implementation shape:
  - Go service in `/home/manuel/code/wesen/2026-03-27--mysql-ide`
  - separate `Deployment`/`Service`/`Ingress` in namespace `coinvault`
  - fixed CoinVault MySQL read-only contract
  - OIDC-backed auth through the existing `coinvault-web` client
  - narrow read-only SQL plus server-owned schema/sample endpoints
- finish the remaining repo hygiene and operator documentation work before changing the runtime contract further
- keep reusing `coinvault-runtime` for the shared read-only DB and OIDC contract unless the service later needs a meaningfully different secret boundary

## Current Outcome

The current implementation is already usable:

- `https://coinvault-sql.yolo.scapegoat.dev/healthz` returns the expected fixed DB/auth contract
- the root UI redirects anonymous users to Keycloak
- an authenticated session can browse the CoinVault schema
- sample reads from `products` succeed
- unsafe statements such as `DELETE FROM products` are rejected server-side
- the app repo now has a local README describing env vars, local `dev` auth mode, OIDC mode, and the K3s deployment contract
- the ticket now has an operator rollout/rollback playbook for rebuilding the image, applying manifests, updating Keycloak, validating behavior, and choosing the smallest safe rollback scope
- Argo reports the parent `coinvault` application as `Synced Healthy`

The most important implementation detail from the live rollout is that schema inspection needed explicit column aliases for `sqlx` scanning against MySQL metadata responses. That bug only surfaced during the authenticated browser smoke test and is now fixed in the app repo.

The main remaining operational caveat is release hygiene: the app repo currently has no configured Git remote, so the Go implementation can be committed locally but not pushed until a remote is added.

## Topics

- coinvault
- k3s
- mysql
- gitops
- debugging

## Tasks

See [tasks.md](./tasks.md) for the current task list.

## Changelog

See [changelog.md](./changelog.md) for recent changes and decisions.

## Structure

- design/ - Architecture and design documents
- reference/ - Prompt packs, API contracts, context summaries
- playbook/ - Command sequences and test procedures
- scripts/ - Temporary code and tooling
- various/ - Working notes and research
- archive/ - Deprecated or reference-only artifacts

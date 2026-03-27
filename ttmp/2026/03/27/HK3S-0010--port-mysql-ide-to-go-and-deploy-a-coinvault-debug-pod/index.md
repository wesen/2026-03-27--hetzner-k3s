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
Summary: "Design and planning ticket for porting the MySQL IDE prototype to Go and deploying it as an authenticated CoinVault SQL debug workload on K3s."
LastUpdated: 2026-03-27T17:24:00-04:00
WhatFor: "Use this ticket to design the Go port of the MySQL IDE prototype and the GitOps deployment of an authenticated CoinVault SQL debug tool against the cluster MySQL service."
WhenToUse: "Read this when planning or implementing a browser-based SQL debug tool for CoinVault on K3s."
---

# Port MySQL IDE to Go and deploy a CoinVault debug pod

## Overview

This ticket covers two linked pieces of work:

- port the existing prototype in `/home/manuel/code/wesen/2026-03-27--mysql-ide` from `HTML + Node proxy` into a real `Go + HTML` application
- deploy that application as an authenticated debug workload alongside CoinVault on the K3s cluster, wired to the same CoinVault MySQL database contract

The main point is not to create a generic database admin tool. The point is to create a tightly scoped operator/debug surface for the CoinVault data path so that a human can inspect schema and run safe read-only queries when the app or import path looks wrong.

## Current Step

Step 1 is active: the prototype, the CoinVault runtime contract, the current auth story, and the current MySQL service shape have all been analyzed, and the design/implementation plan is now documented in this ticket.

## Key Links

- Design doc:
  - [01-mysql-ide-port-and-coinvault-debug-deployment-design.md](./design-doc/01-mysql-ide-port-and-coinvault-debug-deployment-design.md)
- Implementation playbook:
  - [01-mysql-ide-implementation-and-deployment-plan.md](./playbook/01-mysql-ide-implementation-and-deployment-plan.md)
- Investigation diary:
  - [01-mysql-ide-investigation-diary.md](./reference/01-mysql-ide-investigation-diary.md)
- Related migration tickets:
  - [HK3S-0007](../HK3S-0007--recreate-the-first-application-on-k3s-using-vault-managed-secrets/index.md)
  - [HK3S-0009](../HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/index.md)

## Status

Current status: **active**

Current recommendation:

- build the tool in `/home/manuel/code/wesen/2026-03-27--mysql-ide`
- deploy it in namespace `coinvault`
- keep it as a separate `Deployment`/`Service`/`Ingress`, not a sidecar in the main CoinVault pod
- configure it against the existing CoinVault MySQL read-only contract
- protect it with OIDC-backed auth
- restrict the SQL surface to safe read-only queries and server-owned schema endpoints

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

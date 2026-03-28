---
Title: Keycloak on K3s implementation diary
Ticket: HK3S-0008
Status: active
Topics:
    - keycloak
    - k3s
    - gitops
    - postgresql
    - vault
DocType: reference
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: Chronological diary for turning the deferred Keycloak-on-K3s ticket into an executable implementation plan and rollout.
LastUpdated: 2026-03-28T15:56:50-04:00
WhatFor: Use this to review the exact decisions, failures, and implementation path for HK3S-0008.
WhenToUse: Read this when continuing or reviewing the Keycloak-on-K3s migration work.
---

# Keycloak on K3s implementation diary

## Goal

Move shared Keycloak onto K3s under Argo CD without losing the current external Keycloak rollback path, and now do it using the shared PostgreSQL service that already exists on the cluster.

## Step 1: Tighten the ticket now that PostgreSQL is live and define the correct database-provisioning pattern

The original version of this ticket was still mostly a placeholder. It correctly deferred the move, but it left a lot of important implementation questions too open because the platform was not ready yet. That changed after Vault, VSO, the first migrated app, and shared PostgreSQL all became live.

The first thing I did in this implementation pass was tighten the ticket around one concrete operational conclusion: if Keycloak moves onto K3s, it should use the shared PostgreSQL service and should not use Terraform to create its internal database and role.

That required a reusable pattern doc, because the same question is going to come up again for future apps: “How do we declaratively create PostgreSQL internal objects if Kubernetes can only manage the server?” I wrote the answer down in:

- [vault-backed-postgres-bootstrap-job-pattern.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/vault-backed-postgres-bootstrap-job-pattern.md)

The conclusion is:

- use Vault as the source of truth
- use VSO to sync the secrets
- use an idempotent bootstrap `Job` to create the application database and role
- keep the application deployment on a least-privilege runtime credential

Then I updated HK3S-0008 itself so it is no longer just “maybe one day move Keycloak”:

- shared PostgreSQL is now the preferred backing store
- the bootstrap `Job` pattern is the intended way to provision Keycloak’s database
- the next implementation question is packaging and rollout, not whether the cluster can plausibly host the service

### What I did
- Added the reusable docs page for Vault-backed PostgreSQL bootstrap Jobs.
- Added a real design doc for HK3S-0008.
- Added this diary so the implementation trail is recorded as the ticket moves from deferred planning into actual rollout.
- Updated the index, task list, and plan to reflect that shared PostgreSQL now changes the shape of the ticket.

### Why
- The ticket needed a stronger default implementation path before any manifests were added.
- The PostgreSQL bootstrap pattern is a platform concern, not just a Keycloak concern.

### What worked
- The new docs unify the database-provisioning answer with the existing Vault/VSO and Argo CD model.
- The ticket can now be executed task by task instead of requiring fresh design work from scratch.

### What didn't work
- Nothing failed technically yet, but the old ticket text was no longer precise enough to guide safe implementation.

### What I learned
- Once shared PostgreSQL exists, the most important decision is not “should Keycloak use a database?” It is “who owns the creation of the database and role?”

### What should be done in the future
- Choose the packaging model explicitly and start the actual Keycloak package scaffold.

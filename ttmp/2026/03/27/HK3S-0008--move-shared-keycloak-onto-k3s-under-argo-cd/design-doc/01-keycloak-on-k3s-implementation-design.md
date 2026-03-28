---
Title: Keycloak on K3s implementation design
Ticket: HK3S-0008
Status: active
Topics:
    - keycloak
    - k3s
    - gitops
    - postgresql
    - vault
DocType: design
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../docs/vault-backed-postgres-bootstrap-job-pattern.md
      Note: Reusable pattern doc for provisioning the Keycloak database and role inside the shared PostgreSQL service
    - Path: ../../../../../../gitops/kustomize/postgres/statefulset.yaml
      Note: Current shared PostgreSQL service that should back the future in-cluster Keycloak deployment
    - Path: ../../../../../../gitops/kustomize/postgres/vault-static-secret.yaml
      Note: Existing Vault/VSO pattern that the Keycloak package should mirror for database credentials
ExternalSources: []
Summary: Detailed design for moving shared Keycloak onto K3s now that the cluster has Vault, VSO, a proven application path, and shared PostgreSQL.
LastUpdated: 2026-03-28T15:56:50-04:00
WhatFor: Use this to understand the concrete design choices for a future Keycloak-on-K3s implementation pass.
WhenToUse: Read this before adding the Keycloak Argo application and manifests.
---

# Keycloak on K3s implementation design

## Current design decision

The Keycloak move should now be treated as a normal platform application rollout, not as a vague future migration.

The preferred design is:

- deploy Keycloak on K3s behind a parallel hostname
- use the shared PostgreSQL service as the backing store
- provision the Keycloak database and role with a Vault-backed PostgreSQL bootstrap `Job`
- keep realm and client configuration managed by Terraform
- keep `auth.scapegoat.dev` external until the K3s instance proves Vault login and at least one real application login

## Why this is the right shape now

The original ticket kept several major design questions open because the platform had not proven itself yet. That is no longer true.

What is already live:

- Vault on K3s
- Vault Kubernetes auth
- Vault OIDC operator login
- Vault Secrets Operator
- a first migrated application under Argo CD
- shared PostgreSQL

That means the remaining uncertainty is no longer “can the cluster host this?” The uncertainty is now:

- how to cut over safely
- how to preserve operator access during failure
- how to recreate realms and clients cleanly

## Packaging model

Use repo-owned Kustomize manifests with the official Keycloak image, not an external chart as the primary runtime source.

Why:

- this repo has already moved toward repo-owned manifests for long-lived services
- the external chart path was brittle on the MySQL slice
- Keycloak is important enough that debugging should happen against manifests we own directly

The package should live at:

- `gitops/kustomize/keycloak`
- `gitops/applications/keycloak.yaml`

## Persistence model

Use the shared PostgreSQL service at:

- `postgres.postgres.svc.cluster.local:5432`

Provision:

- database: `keycloak`
- role: `keycloak_app`

Do not use Terraform to create those internal PostgreSQL objects. Use the bootstrap `Job` pattern documented at:

- [vault-backed-postgres-bootstrap-job-pattern.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/vault-backed-postgres-bootstrap-job-pattern.md)

## Secret model

Use Vault as the source of truth for three secret classes:

1. shared PostgreSQL admin bootstrap credential
2. Keycloak runtime database credential
3. Keycloak bootstrap admin credential

Suggested Vault paths:

- `kv/infra/postgres/cluster`
- `kv/apps/keycloak/prod/database`
- `kv/apps/keycloak/prod/bootstrap-admin`

Suggested Kubernetes service accounts:

- `keycloak`
- `keycloak-db-bootstrap`

Suggested policy split:

- `keycloak` can read runtime DB credential and bootstrap-admin secret
- `keycloak-db-bootstrap` can read runtime DB credential plus shared PostgreSQL bootstrap secret

## Configuration model

The Keycloak deployment should terminate TLS at Traefik and run HTTP internally.

The expected runtime shape is:

- `KC_DB=postgres`
- `KC_DB_URL_HOST=postgres.postgres.svc.cluster.local`
- `KC_DB_URL_PORT=5432`
- `KC_DB_URL_DATABASE=keycloak`
- `KC_DB_USERNAME=keycloak_app`
- `KC_DB_PASSWORD=<from Vault/VSO>`
- `KC_HTTP_ENABLED=true`
- `KC_PROXY_HEADERS=xforwarded`
- `KC_HOSTNAME=auth.yolo.scapegoat.dev`
- `KC_HEALTH_ENABLED=true`
- `KC_METRICS_ENABLED=true`

Bootstrap admin should come from the synced secret, not inline literals.

## Migration strategy

Do not do direct database migration first.

The preferred migration strategy is:

1. stand up a clean Keycloak instance on K3s
2. recreate the `infra` realm and clients using the existing Terraform modules against the parallel K3s hostname
3. reconfigure Vault and at least one application to authenticate against the new Keycloak
4. verify operator login and application login
5. only then decide whether and how to cut over `auth.scapegoat.dev`

Why:

- current realm/client state is already expressed in Terraform to a meaningful degree
- GitHub-backed users can often be re-created naturally on login
- it keeps the migration reviewable and reversible

## Hostname strategy

Use a parallel hostname first:

- `auth.yolo.scapegoat.dev`

That avoids immediate replacement of the existing control plane and matches the pattern already used successfully for:

- Vault
- CoinVault
- the MySQL IDE
- Pretext

## Rollback model

The rollback line should stay simple:

- if the parallel K3s Keycloak fails, keep using `auth.scapegoat.dev`
- do not change Vault or application OIDC providers permanently until the K3s instance is validated

This means:

- external Keycloak remains the break-glass control plane during the parallel phase
- K3s Keycloak is additive until the final cutover decision

## Diagram

```text
            external today
Vault / apps ------------> auth.scapegoat.dev

parallel future state
                     +------------------------------+
                     | K3s cluster                  |
                     |                              |
                     |  Keycloak Deployment         |
                     |    -> auth.yolo.scapegoat.dev|
                     |                              |
                     |  db-bootstrap Job            |
                     |    -> shared Postgres        |
                     |                              |
                     |  VSO                         |
                     |    -> runtime secrets        |
                     +------------------------------+
                                 |
                                 v
                    postgres.postgres.svc.cluster.local
```

## Immediate implementation sequence

1. update the ticket and tasks around the bootstrap `Job` pattern
2. choose and document the packaging model
3. add the Keycloak package scaffolding
4. add Vault policies, roles, and secret bootstrap helpers
5. add the bootstrap `Job`
6. deploy Keycloak on the parallel hostname
7. validate admin login
8. prove Terraform can target the new instance for realm/client recreation

## Review checklist

- Is shared PostgreSQL the backing store?
- Is the database bootstrap handled by a Job rather than Terraform?
- Are runtime and bootstrap secrets split correctly?
- Is the hostname parallel rather than cutover-first?
- Is the package repo-owned and Argo-managed?
- Does the migration strategy preserve the external Keycloak as the rollback path?

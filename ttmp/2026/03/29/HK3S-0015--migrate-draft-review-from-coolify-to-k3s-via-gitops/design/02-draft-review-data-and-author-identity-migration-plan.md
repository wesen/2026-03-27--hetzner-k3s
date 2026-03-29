---
Title: Draft Review data and author identity migration plan
Ticket: HK3S-0015
Status: active
Topics:
    - draft-review
    - postgres
    - keycloak
    - data-migration
    - terraform
DocType: design-doc
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/wesen/2026-03-24--draft-review/pkg/auth/service.go
      Note: Authenticated user creation flow
    - Path: /home/manuel/code/wesen/2026-03-24--draft-review/pkg/auth/postgres.go
      Note: Postgres auth identity matching and upsert behavior
    - Path: /home/manuel/code/wesen/2026-03-24--draft-review/pkg/db/migrations/0003_user_auth_identity.sql
      Note: Schema columns that bind app users to issuer and subject
    - Path: /home/manuel/code/wesen/terraform/keycloak/apps/draft-review/envs/k3s-parallel/main.tf
      Note: Parallel K3s Keycloak env for the Draft Review realm/client
ExternalSources: []
Summary: Plan for copying the Draft Review database from the old Coolify Postgres instance into the K3s cluster and re-binding the `wesen` author row to a Terraform-managed Keycloak user on the K3s issuer.
LastUpdated: 2026-03-29T16:00:00-04:00
WhatFor: Explain the safest way to migrate existing Draft Review content and author identity to the new K3s deployment without losing article ownership.
WhenToUse: Use when moving hosted Draft Review data into the cluster and wiring the first real Keycloak author account for K3s login.
---

# Draft Review data and author identity migration plan

## Why this plan exists

The first live K3s rollout proved the application stack itself:

- the app deploys and serves traffic on `https://draft-review.yolo.scapegoat.dev`
- private GHCR image pulls work through the Vault-backed pull-secret path
- the shared Postgres bootstrap job creates the `draft_review` database and role
- the app is wired to the K3s Keycloak realm at `https://auth.yolo.scapegoat.dev/realms/draft-review`

What it does **not** preserve yet is the existing content and author identity from the old hosted deployment.

If we stop here, the K3s Draft Review deployment is a fresh empty instance.

The next migration slice therefore has two linked goals:

- copy the old Draft Review application data from the Coolify-hosted Postgres database into the K3s cluster
- make sure the `wesen` author row in that copied database matches a real K3s Keycloak user so logging in still opens the correct articles

## What the app actually uses to identify authors

Draft Review does not identify an authenticated author only by email.

The app code in [service.go](/home/manuel/code/wesen/2026-03-24--draft-review/pkg/auth/service.go) and [postgres.go](/home/manuel/code/wesen/2026-03-24--draft-review/pkg/auth/postgres.go) shows this flow:

1. the OIDC callback produces an authenticated identity
2. the app looks for an existing user row by:
   - `auth_issuer`
   - `auth_subject`
3. only if no such row exists does it create or upsert a user by email

That means a copied database only works seamlessly if the imported `users` row for Manuel is updated to match the new K3s Keycloak issuer and the new K3s Keycloak user subject.

## Real source-system findings

The old hosted Draft Review database is still reachable on the old Coolify host through the container:

- Postgres container: `go1o5tbegalwy3kesshq3hcp`
- database: `draft_review`

The current hosted `users` table contains exactly two rows:

```text
email                 | name             | auth_issuer                                     | auth_subject
wesen@ruinwesen.com   | Manuel Odendahl  | https://auth.scapegoat.dev/realms/draft-review  | ad1655b1-91ad-4b0b-8200-b33b8526244a
author@example.com    | Draft Author     | https://auth.scapegoat.dev/realms/draft-review  | 3a0357ef-9917-4cd7-9739-613ae23cc94b
```

Important implication:

- Manuel’s existing articles and ownership records point at the user row whose identity currently belongs to the **old** issuer and **old** Keycloak subject UUID

The source schema is also slightly older than the current application schema:

- `article_assets` does not exist in the hosted database yet

That means the migration should preserve the **current target schema** in K3s and import the **old data** into it, rather than dropping the K3s schema and restoring an older schema wholesale.

## Recommended migration strategy

### High-level recommendation

Use this sequence:

1. create a Terraform-managed `wesen` user in the K3s Draft Review realm
2. export the old Draft Review database as data
3. import that data into the cluster `draft_review` database
4. update the imported `users` row for Manuel so:
   - `auth_issuer = https://auth.yolo.scapegoat.dev/realms/draft-review`
   - `auth_subject = <new K3s Keycloak user id>`
5. validate that logging in as `wesen` opens the existing data

This is better than hoping email alone will re-bind the old row, because the application first resolves the author by `(issuer, subject)`.

## Why not just recreate the user manually

You could create the Keycloak user manually in the admin console and then patch the DB. That would work operationally.

But for this repo, Terraform is the better steady-state control plane because:

- Keycloak realm and client config already lives in the Terraform repo
- the new K3s Draft Review realm already lives at:
  - [main.tf](/home/manuel/code/wesen/terraform/keycloak/apps/draft-review/envs/k3s-parallel/main.tf)
- the Terraform provider already supports declarative users through `keycloak_user`

So the recommended model is:

```text
Terraform
  -> creates realm
  -> creates browser client
  -> creates the `wesen` user

DB migration
  -> rewrites the imported author row to the Terraform-created user identity
```

## Why not copy the full source schema wholesale

The source hosted database is not on the latest migration level.

If we restore schema plus data from the old host straight over the new cluster DB, we risk:

- clobbering newer tables
- losing newly added columns
- restoring an older schema shape that the current app binary no longer expects

The safer approach is:

```text
K3s target DB
  -> keep current app schema

Hosted source DB
  -> export data rows

Import job
  -> load source data into current target schema
  -> patch author identity rows
```

This is the same basic pattern used in mature app migrations:

- target owns the canonical schema
- source contributes the data payload

## Proposed implementation shape

### Part 1. Terraform-managed `wesen` user

Add a `keycloak_user` resource to the K3s parallel Draft Review env.

Expected attributes:

- username: `wesen`
- email: `wesen@ruinwesen.com`
- first name: `Manuel`
- last name: `Odendahl`
- enabled: `true`
- email verified: `true`
- initial password supplied from local secrets, not git

Why we need it:

- this creates a concrete Keycloak subject UUID in the K3s Draft Review realm
- that subject UUID becomes the new `users.auth_subject` for the Manuel row in Postgres

### Part 2. Source database export

Create a ticket-local script in `scripts/` that exports the old hosted Draft Review data.

The export script should:

- run over SSH against the Coolify host
- use `docker exec go1o5tbegalwy3kesshq3hcp ... pg_dump`
- prefer `--data-only --column-inserts`
- write the result into the ticket workspace for traceability

Why `--column-inserts`:

- the source schema is older than target
- column-targeted inserts tolerate added columns on the target schema better than raw `COPY` or positional inserts

### Part 3. Target database safety snapshot

Even though the target DB is currently mostly empty, create a pre-import snapshot anyway.

That script should:

- connect to `postgres.postgres.svc.cluster.local`
- export the current cluster `draft_review` database
- store the dump in the ticket `scripts/` or ticket workspace output area

This keeps rollback honest and reviewable.

### Part 4. Data import

Import the old data into the K3s `draft_review` database using a repeatable, ticket-local script.

The import step should:

- truncate or recreate the target application tables in a controlled order
- load the exported data-only SQL
- leave the current migrated schema intact

### Part 5. Identity rewrite SQL

After the Terraform user exists, patch the imported Manuel row.

Pseudocode:

```sql
update users
set auth_issuer = 'https://auth.yolo.scapegoat.dev/realms/draft-review',
    auth_subject = '<new-k3s-keycloak-user-id>',
    email = 'wesen@ruinwesen.com',
    name = 'Manuel Odendahl',
    updated_at = now()
where email = 'wesen@ruinwesen.com';
```

This makes the imported content belong to the new K3s-authenticated Manuel identity.

### Part 6. Validation

Validation should prove more than `/healthz`.

Minimum checks:

- login through `https://auth.yolo.scapegoat.dev/realms/draft-review`
- `GET /api/me` returns authenticated user `wesen@ruinwesen.com`
- the article list is not empty if the source DB had authored articles
- article detail routes open existing content
- `owner_user_id` links still resolve to the updated Manuel row

## Treatment of the second hosted user

The second hosted row is:

- `author@example.com`
- `Draft Author`

That looks like a seeded or placeholder author rather than a known production human identity.

Recommendation:

- do not block the Manuel migration on that user
- import the row as part of the DB copy
- decide later whether to:
  - leave it as a historical row
  - create a second K3s Keycloak user for it
  - or remap/archive it explicitly

## Media migration note

Draft Review has a persistent media root on K3s now, but this plan is specifically about the DB and the author identity rewrite.

If the old hosted app has actual uploaded files that matter, that should be inspected as a separate migration step:

- inspect hosted container mounts
- locate the old media directory
- copy files into the PVC-backed path

That is adjacent work, but not required to answer the current DB + Keycloak-user question.

## Recommended execution order

1. Add Terraform-managed `wesen` user to `draft-review/envs/k3s-parallel`
2. Apply Terraform and capture the resulting Keycloak user ID
3. Export the hosted `draft_review` DB into a ticket-local artifact
4. Snapshot the current cluster `draft_review` DB
5. Import hosted data into the cluster DB
6. Rewrite the Manuel user row to the new issuer and subject
7. Validate login and article ownership in the K3s app
8. Update the ticket diary and docs with the actual final mapping

## Recommendation

Yes, we should do both:

- copy the Draft Review database
- create the `wesen` user declaratively in Terraform

But the correct migration is **not** “copy DB and hope email matches.”

The correct migration is:

```text
Terraform-created K3s Keycloak user
  -> gives us the new subject UUID

Hosted DB import
  -> brings over articles, reviews, and the old author row

SQL rewrite
  -> rebinds the Manuel row from old issuer/subject to new issuer/subject
```

That preserves the real authored content while keeping the new cluster identity plane as the source of truth.

---
Title: "Use a Vault-Backed PostgreSQL Bootstrap Job for In-Cluster Database Provisioning"
Slug: "vault-backed-postgres-bootstrap-job-pattern"
Short: "Provision PostgreSQL databases and roles declaratively in K3s using Argo CD, Vault Secrets Operator, and an idempotent bootstrap Job instead of Terraform."
Topics:
- vault
- postgresql
- kubernetes
- argocd
- gitops
- vso
- jobs
Commands:
- kubectl
- psql
- git
- vault
Flags: []
IsTopLevel: true
IsTemplate: false
ShowPerDefault: true
SectionType: Tutorial
---

## What This Page Covers

This page explains the pattern this repository should use when an application needs its own PostgreSQL database, PostgreSQL role, and grants inside the shared cluster PostgreSQL service. It is written for the current K3s and Argo CD platform shape:

- PostgreSQL server is already GitOps-managed under Argo CD
- Vault is the source of truth for credentials
- Vault Secrets Operator syncs working copies of secrets into Kubernetes
- application packages live under `gitops/kustomize/<app>`

The key idea is that Kubernetes can declaratively manage the PostgreSQL server, but it cannot natively declare internal PostgreSQL objects such as databases, roles, and grants. For those internal objects, this repo should use an idempotent bootstrap `Job` that runs SQL against the shared cluster PostgreSQL service.

This pattern is the right fit for this repository because it keeps ownership aligned:

- Argo CD owns the Kubernetes resources
- Vault owns the secret values
- the bootstrap `Job` owns the SQL side effects
- the application deployment consumes only its least-privilege runtime credential

## Why This Pattern Exists

A new intern will usually ask a reasonable question: “Why can’t we just create the PostgreSQL database in Terraform?” The short answer is that Terraform is not the best control loop for in-cluster application bootstrap.

Terraform is good for:

- servers
- DNS
- cloud load balancers
- external Keycloak configuration
- static shared infrastructure contracts

Terraform is poor for:

- application-scoped database provisioning inside a live GitOps cluster
- repeated database changes driven by application rollout order
- secrets that already flow through Vault and VSO
- in-cluster bootstrap steps that should re-run safely as part of reconciliation

Kubernetes also does not have a built-in resource like `PostgresDatabase` in core APIs. So there are only three realistic choices:

- use a PostgreSQL-aware operator
- use Terraform or another external provisioner
- use a Kubernetes `Job` or controller that runs SQL

For the current single-node platform, the `Job` pattern is the simplest thing that matches the rest of the repo.

## Mental Model

Use this mental model:

```text
Vault
  -> stores cluster admin and app database credentials

Vault Secrets Operator
  -> syncs secrets into Kubernetes

Bootstrap Job
  -> uses admin credential
  -> creates database if missing
  -> creates role if missing
  -> sets password
  -> grants ownership/privileges

Application Deployment
  -> uses only the app runtime credential
  -> never sees the cluster admin credential
```

This separation matters. The bootstrap `Job` needs enough power to create database objects. The application should not.

## The Three Secret Classes

For this pattern, think in terms of three secret classes:

### 1. Cluster PostgreSQL admin credential

This is the shared PostgreSQL bootstrap/admin identity. In the current repo, it comes from the shared PostgreSQL service slice in [HK3S-0009 index](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/index.md).

In practice this means:

- host: `postgres.postgres.svc.cluster.local`
- port: `5432`
- bootstrap user/password in Vault

The bootstrap `Job` needs this.

### 2. Application database credential

This is the app-specific PostgreSQL role and password. For example:

- database: `keycloak`
- user: `keycloak_app`
- password: generated in Vault

The bootstrap `Job` needs this to create or update the role. The application deployment also needs this to connect at runtime.

### 3. Bootstrap admin for the application itself

Some apps need their own first-login bootstrap secret separate from the database credential. Keycloak is the obvious example:

- `KC_BOOTSTRAP_ADMIN_USERNAME`
- `KC_BOOTSTRAP_ADMIN_PASSWORD`

This is not a PostgreSQL concern, but it usually travels through the same Vault/VSO pattern.

## Recommended Kubernetes Resource Shape

For an app like Keycloak, the resource package should usually contain:

- `namespace.yaml`
- `serviceaccount.yaml`
- `vault-connection.yaml`
- `vault-auth.yaml`
- `vault-static-secret.yaml` for the runtime DB secret
- `vault-static-secret.yaml` for the bootstrap-admin secret if needed
- `vault-static-secret.yaml` for the PostgreSQL admin bootstrap secret if the Job needs it
- `db-bootstrap-job.yaml`
- `deployment.yaml`
- `service.yaml`
- `ingress.yaml`

If the bootstrap step should run before the main deployment, use Argo CD sync waves or hook annotations so the database objects exist before the app starts.

## Recommended Vault Shape

Keep the secret paths explicit and boring.

Example:

```text
kv/infra/postgres/cluster
kv/apps/keycloak/prod/database
kv/apps/keycloak/prod/bootstrap-admin
```

Then use least-privilege Vault policies:

- app runtime service account can read only its runtime database secret and bootstrap-admin secret if needed
- bootstrap `Job` service account can read:
  - cluster PostgreSQL admin secret
  - app database bootstrap secret

That keeps the admin credential out of the long-running application pod.

## Example Flow

Here is the full desired flow in pseudocode:

```text
1. Operator writes or rotates secrets in Vault
2. VSO syncs:
   - postgres cluster admin secret
   - keycloak database secret
   - keycloak bootstrap admin secret
3. Argo applies bootstrap Job
4. Job runs SQL:
   - CREATE ROLE keycloak_app IF MISSING
   - ALTER ROLE keycloak_app PASSWORD ...
   - CREATE DATABASE keycloak IF MISSING
   - GRANT ownership/privileges
5. Argo applies or restarts Keycloak deployment
6. Keycloak connects using only keycloak_app credentials
```

## Example SQL Shape

Make the SQL idempotent. The exact script can vary, but the shape should look like this:

```sql
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'keycloak_app') THEN
    CREATE ROLE keycloak_app LOGIN PASSWORD 'replace-me';
  ELSE
    ALTER ROLE keycloak_app WITH LOGIN PASSWORD 'replace-me';
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'keycloak') THEN
    CREATE DATABASE keycloak OWNER keycloak_app;
  END IF;
END
$$;
```

Then, if needed, connect to the app database and add grants or extensions:

```sql
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak_app;
```

The important property is that the script can run twice without breaking the cluster.

## Example Job Shape

This is not a copy-paste manifest, but it shows the intended structure:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: keycloak-db-bootstrap
  namespace: keycloak
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  template:
    spec:
      restartPolicy: OnFailure
      serviceAccountName: keycloak-db-bootstrap
      containers:
        - name: bootstrap
          image: postgres:16-alpine
          env:
            - name: PGHOST
              valueFrom: ...
            - name: PGPORT
              valueFrom: ...
            - name: PGUSER
              valueFrom: ...
            - name: PGPASSWORD
              valueFrom: ...
            - name: APP_DB_NAME
              valueFrom: ...
            - name: APP_DB_USER
              valueFrom: ...
            - name: APP_DB_PASSWORD
              valueFrom: ...
          command:
            - /bin/sh
            - -ec
            - |
              psql -d postgres <<'SQL'
              ...
              SQL
```

## Why Not Give the App the Admin Credential

Do not do this:

- inject the PostgreSQL admin password into the main application pod
- let the app create its own database on startup

That seems easier at first, but it weakens the security boundary and makes startup behavior harder to reason about. The app should fail if its database contract is missing, not silently mutate shared infrastructure with elevated credentials.

## Why Not Use Terraform for This

Using Terraform for the internal PostgreSQL objects would split the ownership model in an awkward way:

```text
Argo CD
  -> owns PostgreSQL server and app manifests

Terraform
  -> owns PostgreSQL databases and roles

Vault/VSO
  -> owns the credentials used by both
```

That is not impossible, but it is harder to review and harder to recover. The `Job` pattern keeps the bootstrap operation inside the same GitOps package as the app that needs it.

## When to Use an Operator Instead

If the platform grows and you need:

- multi-instance PostgreSQL clusters
- richer backup automation
- managed failover
- stronger lifecycle APIs for databases and users

then a PostgreSQL-aware operator may be worth it.

For the current repo, that is extra moving parts. The bootstrap `Job` pattern is the simpler fit.

## How This Applies to HK3S-0008

For Keycloak on K3s, this repo should use this exact pattern:

1. keep shared PostgreSQL in the `postgres` namespace
2. add a Keycloak package in `gitops/kustomize/keycloak`
3. sync a Keycloak-specific runtime DB secret from Vault
4. sync a PostgreSQL admin bootstrap secret from Vault for the Job only
5. run a `keycloak-db-bootstrap` Job to create the `keycloak` database and `keycloak_app` role
6. start Keycloak using only the `keycloak_app` credential

That means the ticket should not say “use Terraform to create the database.” It should say “use a Vault-backed bootstrap Job.”

## Review Checklist

When reviewing a new app package that uses this pattern, check these points:

- Does the bootstrap `Job` use an admin credential while the app deployment does not?
- Are the Vault policies least-privilege and scoped to the right service accounts?
- Is the SQL idempotent?
- Does the app runtime secret contain only the app user, password, host, port, and database?
- Are sync waves or hooks preventing the app from starting before the bootstrap `Job` can run?
- Is the bootstrap admin secret for the app kept separate from the database secrets when appropriate?

## Related Files in This Repo

- Shared PostgreSQL service:
  - [statefulset.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/postgres/statefulset.yaml)
  - [vault-static-secret.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/postgres/vault-static-secret.yaml)
- Shared PostgreSQL rollout ticket:
  - [HK3S-0009 index](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/index.md)
- Keycloak migration ticket:
  - [HK3S-0008 index](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0008--move-shared-keycloak-onto-k3s-under-argo-cd/index.md)

## Summary

For this repository, the correct default for “create an app-specific PostgreSQL database inside the shared cluster PostgreSQL instance” is:

- not Terraform
- not application self-bootstrap with admin credentials
- not hand-run SQL in a shell

It is:

- Vault as source of truth
- VSO as Kubernetes secret sync
- Argo CD as package owner
- an idempotent bootstrap `Job` for the PostgreSQL internal objects

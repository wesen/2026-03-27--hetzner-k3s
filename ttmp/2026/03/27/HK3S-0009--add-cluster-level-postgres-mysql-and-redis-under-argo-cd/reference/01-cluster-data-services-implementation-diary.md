---
Title: Cluster data services implementation diary
Ticket: HK3S-0009
Status: active
Topics:
    - k3s
    - infra
    - gitops
    - migration
DocType: reference
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: Chronological diary for introducing shared cluster data services on K3s, starting with MySQL and now including PostgreSQL, Redis, and the first live off-cluster backup path.
LastUpdated: 2026-03-29T16:45:00-04:00
WhatFor: Use this to review the exact implementation trail for the shared MySQL, PostgreSQL, and Redis slices.
WhenToUse: Read this when continuing or reviewing HK3S-0009.
---

# Cluster data services implementation diary

## Goal

Introduce the first shared cluster data service on K3s in a way that solves a real application blocker immediately and establishes a repeatable pattern for later Postgres or Redis work.

## Step 1: Reactivate the ticket around a concrete MySQL blocker instead of the original abstract three-service plan

This ticket originally existed as a future placeholder for “someday we should add Postgres, MySQL, and Redis.” That was the right shape when the platform itself was still being built. Once the CoinVault migration started, the ticket stopped being theoretical. CoinVault’s current MySQL host turned out to be a Coolify-internal Docker alias, which K3s cannot resolve. That makes shared MySQL a real blocker, not a premature optimization.

I re-read the ticket, confirmed the original deferral rationale, and then narrowed the scope deliberately. The right move is not “build all three services now.” The right move is “prove one shared service cleanly, starting with MySQL, because that unblocks the active application migration.” This keeps the scope disciplined while still solving the real operational problem in front of us.

### What I did
- Re-opened the deferred data-services ticket as an active MySQL-first implementation slice.
- Updated the ticket index, task list, and changelog to reflect the new scope.
- Added a dedicated diary and a MySQL-first design document so the work is no longer buried in ad hoc terminal history.

### Why
- The active CoinVault migration exposed a real runtime dependency mismatch between Coolify networking and K3s networking.
- MySQL now has a concrete consumer, which makes the design easier to judge.

### What worked
- The blocker translated cleanly into a smaller and more defensible service-platform slice.

### What didn't work
- The original deferred framing was now too vague to guide implementation, so I had to tighten it before doing real work.

### What I learned
- Shared services become much easier to justify once a real application has a concrete dependency mismatch.

### What should be done in the future
- Choose the MySQL packaging and secret model next, then scaffold the GitOps deployment.

## Step 2: Choose the chart-plus-VSO model and scaffold shared MySQL

Once I switched the ticket from “someday all three services” to “MySQL first,” the next decision was packaging. I wanted the smallest path that still looked like the long-term platform, not a one-off hand-built StatefulSet. I checked the official Bitnami MySQL chart sources directly because `helm` is not installed locally. The current official chart metadata showed chart version `14.0.5`, app version `9.4.0`, and, more importantly, documented support for `auth.existingSecret`.

That was the key fit with the platform we already built. VSO can render a Kubernetes `Secret` with the keys the chart expects, and the chart can consume that secret without inventing a second secret-management pattern. So I added:

- [`gitops/applications/mysql.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/mysql.yaml)
  - Argo CD application for the Bitnami MySQL chart
- [`vault/policies/kubernetes/mysql.hcl`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/mysql.hcl)
  - least-privilege Vault policy for the MySQL service account
- [`vault/roles/kubernetes/mysql.json`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/mysql.json)
  - Kubernetes auth role bound to service account `mysql` in namespace `mysql`
- [`bootstrap-cluster-mysql-secrets.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-cluster-mysql-secrets.sh)
  - generates or preserves the passwords at `kv/infra/mysql/cluster`
- [`validate-cluster-mysql.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-cluster-mysql.sh)
  - validates the Argo app, the StatefulSet rollout, and a real SQL login inside the pod

I kept this slice intentionally narrow:

- standalone MySQL only
- one first database `gec`
- one first user `coinvault_ro`
- no Redis or Postgres changes yet

One important limitation remains visible on purpose: the Bitnami chart’s simple built-in user bootstrap does not encode a true read-only permission model for `coinvault_ro`. For this first slice, the value name stays `coinvault_ro` because that matches the current app contract, but the stricter grant model should be revisited with init SQL or a follow-up hardening pass.

### What I did
- Checked the official Bitnami chart metadata and values using primary sources.
- Chose the chart-plus-VSO model.
- Added the MySQL Argo application.
- Added the Vault policy and Kubernetes role for the MySQL service account.
- Added the Vault secret bootstrap and deployment validation scripts.

### Why
- The chart already exposes the exact secret interface we need through `auth.existingSecret`.
- Reusing VSO keeps Vault as the source of truth without inventing a second pattern.

### What worked
- The chart contract and the VSO contract fit together cleanly.
- The needed Vault policy surface is tiny and easy to review.

### What didn't work
- `helm` is not installed locally, so I had to inspect the official GitHub chart sources directly instead of using local chart tooling.

### What I learned
- The chart’s `auth.existingSecret` support is the main reason this can be cleanly integrated into the existing GitOps plus Vault setup.

### What should be done in the future
- Validate the scaffold locally, then bootstrap the Vault secret path, write the new Vault role/policy into the live K3s Vault, and deploy the chart.

## Step 3: Validate the scaffold and isolate unrelated carry-over changes before the first MySQL checkpoint

Before committing the MySQL scaffold, I needed to make sure I was not accidentally mixing together three separate threads of work:

- the new shared-MySQL slice in this ticket
- the still-unfinished CoinVault deployment adjustments
- the separate Keycloak change sitting in the Terraform repo for the CoinVault hostname

That distinction matters because this ticket should stay reviewable as “shared MySQL for K3s,” not “random leftovers from the larger migration.” I checked the local Git state and confirmed there was one unrelated CoinVault change still present in this repo: a pending `COINVAULT_SKIP_DB_CHECK=true` line in the CoinVault deployment. I also confirmed the Terraform repo still had a separate uncommitted Keycloak modification. I left both out of the MySQL checkpoint on purpose.

Then I ran the static validation pass for the MySQL scaffold itself:

- `bash -n scripts/bootstrap-cluster-mysql-secrets.sh`
- `bash -n scripts/validate-cluster-mysql.sh`
- `ruby -e 'require "yaml"; YAML.load_file("gitops/applications/mysql.yaml"); puts "yaml ok"'`
- `git diff --check`
- `docmgr doctor --ticket HK3S-0009 --stale-after 30`

Everything passed. That gave me a clean base for the next commit and for the live rollout that follows it.

### What I did
- Checked the working tree in the K3s repo and in the shared Terraform repo.
- Confirmed the MySQL scaffold is the only thing that should enter the next ticket checkpoint.
- Validated shell syntax, YAML parsing, Git whitespace checks, and `docmgr` health.

### Why
- The ticket needs a clean review boundary.
- Static validation is the cheapest place to catch bad scripts or malformed manifests before touching the live cluster.

### What worked
- The MySQL scaffold passed validation without edits.
- The unrelated CoinVault and Terraform changes were easy to identify and keep separate.

### What didn't work
- The earlier CoinVault pivot left behind partially completed changes in two repos, so I had to explicitly fence them off before continuing.

### What I learned
- Even when the technical design is straightforward, scoping discipline is what keeps GitOps tickets understandable and safe to review.

### What should be done in the future
- Commit the MySQL scaffold as its own checkpoint, then perform the live Vault bootstrap and Argo rollout.

## Step 4: Start the live rollout, hit real upstream chart failures, and pivot to repo-managed Kustomize manifests

After the scaffold checkpoint was committed and pushed, I moved into the live rollout. The first part worked as intended. I fetched the K3s Vault root token from 1Password, re-ran [`bootstrap-vault-kubernetes-auth.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-kubernetes-auth.sh), and wrote the MySQL secret payload into `kv/infra/mysql/cluster`.

That part was not completely smooth. The first run failed with:

- `zsh: permission denied: ./scripts/bootstrap-cluster-mysql-secrets.sh`

The mistake was simple: I had committed the helper scripts without the executable bit. I fixed that locally and re-ran the secret bootstrap using `bash`, which succeeded.

Then I created the Argo CD application and hit the more important failure. Argo reported:

- chart version `14.0.5` was not found in the published Bitnami repository

I checked the published Bitnami `index.yaml` and confirmed that the repository Argo actually uses currently publishes `mysql` chart version `14.0.3`, even though the GitHub chart tree already showed `14.0.5`. I corrected the target revision and retried.

That exposed the next issue:

- the `extraDeploy` values used `namespace: {{ .Release.Namespace }}` without quoting
- Argo failed YAML parsing before Helm could render the template

I fixed the quoting and retried again. That got farther: VSO reconciled cleanly, the `mysql-auth` secret appeared, and the MySQL StatefulSet was created. But the pod then failed with:

- `ErrImagePull`
- `docker.io/bitnami/mysql:9.4.0-debian-12-r1: not found`

At that point the right engineering conclusion changed. This was no longer “a tiny version mismatch.” The external chart path was operationally brittle in a way this repo should not inherit:

- GitHub chart metadata was ahead of the published chart repository
- the published chart’s default image tag was no longer present in the referenced container registry

So I pivoted the runtime packaging while preserving the larger platform contract. I replaced the external chart source with repo-managed Kustomize manifests under [`gitops/kustomize/mysql`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/mysql), using the official `mysql:8.4` image and keeping:

- namespace `mysql`
- service account `mysql`
- Vault Kubernetes auth role `mysql`
- `VaultConnection`, `VaultAuth`, and `VaultStaticSecret`
- service name `mysql.mysql.svc.cluster.local`
- single-node persistent StatefulSet semantics

This is a better fit for the current cluster anyway because:

- the runtime is now fully reviewable in this repo
- image selection is explicit
- future debugging does not depend on a third-party chart release path behaving sanely

One final GitOps detail appeared immediately after the pivot. I updated the live Argo application to point at `gitops/kustomize/mysql`, and Argo correctly complained that the path did not exist yet. That is expected because the new Kustomize directory only exists locally until the next commit and push.

### What I did
- Bootstrapped the live Vault policy, role, and MySQL secret path.
- Fixed the missing executable bit on the helper scripts.
- Investigated and confirmed the chart version mismatch between GitHub and the published Bitnami repo.
- Investigated and confirmed the broken `docker.io/bitnami/mysql` image tag.
- Replaced the external-chart application source with repo-managed Kustomize manifests using `mysql:8.4`.

### Why
- The Vault/VSO model worked and should be kept.
- The external chart path introduced unnecessary runtime risk and debugging ambiguity.
- Repo-managed manifests are easier to review, fix, and keep stable in a small single-cluster platform.

### What worked
- Vault bootstrap and VSO secret delivery worked exactly as intended.
- The new Kustomize manifests rendered locally without errors.
- The official `mysql:8.4` image resolved successfully during local verification.

### What didn't work
- The helper scripts initially lacked the executable bit.
- The Bitnami GitHub tree version did not match the published chart repo version.
- The published chart referenced a container image tag that no longer existed.

### What I learned
- External charts can fail in multiple layers at once: chart version availability, Helm templating behavior, and image publication lifecycle.
- Once a stateful service becomes a real migration dependency, owning the manifests in-repo is often the simpler and more reliable path.

### What should be done in the future
- Commit and push the Kustomize pivot immediately so Argo can fetch the new path.
- Re-run the application refresh and validate the live MySQL StatefulSet and service.

## Step 5: Push the Kustomize source, reconcile the live app, and fix the final Argo drift

Once the repo-managed Kustomize manifests existed, the next requirement was obvious but easy to overlook in the middle of live debugging: Argo CD cannot reconcile a path that only exists on my laptop. I committed and pushed the Kustomize pivot so the application source path actually existed in GitHub, then forced a refresh.

That moved the failure forward again in a useful way. Argo could now read the repo, but it still could not update the existing MySQL StatefulSet in place because the original failed chart deployment had created a different StatefulSet shape. Kubernetes reported:

- updates to forbidden StatefulSet spec fields

This was not a reason to back out the new design. It only meant the old failed object needed to be replaced. Because the pod had never become a working database and the PVC was already retained, I deleted the failed StatefulSet and let Argo recreate it from the desired repo-owned manifest. That worked.

The recreated MySQL pod came up on `mysql:8.4`, but Argo still reported the StatefulSet `OutOfSync`. I compared the desired manifest to the live object and found the same class of problem we had already seen on the demo PostgreSQL slice: Kubernetes had defaulted fields that were not declared in Git. I added those defaults explicitly:

- `updateStrategy`
- `dnsPolicy`
- `restartPolicy`
- `schedulerName`
- `securityContext`
- `serviceAccount`
- container termination-message fields
- `apiVersion` and `kind` on the PVC template

After that revision was pushed, Argo reported:

- `sync=Synced`
- `health=Healthy`

### What I did
- Pushed the repo-managed Kustomize source so Argo could fetch it.
- Deleted the failed chart-created StatefulSet.
- Compared the live and desired StatefulSet specs.
- Added Kubernetes-defaulted fields to the manifest.

### Why
- Argo can only reconcile Git-published state.
- StatefulSet immutability prevented morphing the old chart object into the new repo-owned shape.
- Explicit defaults are necessary when Argo compares live objects strictly.

### What worked
- Recreating the StatefulSet from the repo-owned spec cleanly moved the pod to `mysql:8.4`.
- The default-field alignment cleared the last Argo drift.

### What didn't work
- Simply changing the Application source was not enough because the old failed StatefulSet shape was still present.

### What I learned
- For stateful services, the cleanest migration between packaging models is often “replace the controller while retaining the volume,” not “mutate everything in place.”

### What should be done in the future
- Run the database validation and a consumer-path smoke test, then close the ticket and resume the blocked CoinVault migration.

## Step 6: Validate the final MySQL service from both the server and consumer perspectives

Once Argo was `Synced Healthy`, I ran the validation script:

- [`validate-cluster-mysql.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-cluster-mysql.sh)

That confirmed:

- the Argo application was healthy
- the StatefulSet had rolled out
- the `mysql-auth` secret existed
- SQL worked inside the pod
- the database `gec` existed
- the user `coinvault_ro` existed

I then added one more smoke test aimed at the eventual application contract rather than the server internals. I launched a one-shot client pod using the official `mysql:8.4` image, connected to:

- `mysql.mysql.svc.cluster.local`

and executed:

- `SELECT CURRENT_USER(), DATABASE();`

The result showed:

- current user `coinvault_ro@%`
- current database `gec`

That is the key proof that later app migrations can consume the service through cluster DNS and the VSO-synced credentials, not just that “the database container is running.”

### What I did
- Ran the scripted MySQL validation.
- Ran a one-shot in-cluster client smoke test against the shared service DNS name.
- Deleted the temporary client pod after capturing the result.

### Why
- A healthy StatefulSet is not enough; the ticket needs to prove the actual application-facing contract.

### What worked
- The server validation passed cleanly.
- The application user could connect through the stable service DNS name and reach the expected database.

### What didn't work
- The first version of the smoke test used `kubectl run --rm` in a non-interactive way that Kubernetes rejected, so I switched to a create, wait, log, delete pattern.

### What I learned
- The consumer-path smoke test is worth keeping because it validates DNS, credentials, image pull, and SQL reachability all at once.

## Step 7: Expand the proven MySQL pattern into repo-owned PostgreSQL and Redis scaffolds

Once MySQL was live, the ticket had enough evidence to stop speculating about PostgreSQL and Redis and just implement them using the same platform contract. I added the follow-on design note and concrete ticket tasks first so the rollout would still be reviewable in order instead of looking like “mystery manifests appeared in the repo.”

Then I scaffolded both service slices in parallel:

- shared PostgreSQL under [`gitops/kustomize/postgres`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/postgres)
- shared Redis under [`gitops/kustomize/redis`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/redis)
- Argo CD applications:
  - [`gitops/applications/postgres.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/postgres.yaml)
  - [`gitops/applications/redis.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/redis.yaml)
- Vault Kubernetes-auth policy and role pairs:
  - [`vault/policies/kubernetes/postgres.hcl`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/postgres.hcl)
  - [`vault/roles/kubernetes/postgres.json`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/postgres.json)
  - [`vault/policies/kubernetes/redis.hcl`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/redis.hcl)
  - [`vault/roles/kubernetes/redis.json`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/redis.json)
- Vault secret bootstrap and live validation helpers:
  - [`scripts/bootstrap-cluster-postgres-secrets.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-cluster-postgres-secrets.sh)
  - [`scripts/bootstrap-cluster-redis-secrets.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-cluster-redis-secrets.sh)
  - [`scripts/validate-cluster-postgres.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-cluster-postgres.sh)
  - [`scripts/validate-cluster-redis.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-cluster-redis.sh)

I kept the manifests structurally close to the working MySQL slice so the platform remains coherent:

- one namespace per shared service
- one service account per service
- VaultConnection, VaultAuth, and VaultStaticSecret for credentials
- one single-replica persistent StatefulSet
- one stable cluster DNS name per service

### What I did
- Added the design note and explicit rollout tasks for PostgreSQL and Redis.
- Added the GitOps applications, Kustomize packages, Vault policies, Vault roles, and helper scripts.
- Ran the static validation pass before committing:
  - `bash -n` on the four new helper scripts
  - `kubectl kustomize` on both new Kustomize packages
  - `git diff --check`
  - `docmgr doctor --ticket HK3S-0009 --stale-after 30`

### Why
- MySQL had already proven the manifest, Vault, and VSO model.
- PostgreSQL and Redis are infrastructure siblings now, not research projects.

### What worked
- The two new service slices fit cleanly into the existing repo structure.
- Static validation passed without requiring a redesign.

### What didn't work
- Nothing failed technically at this stage, but it was clear that the live rollout would need 1Password/Vault access again.

### What I learned
- Once the platform contract is solid, adding another stateful service becomes mostly repetition plus careful validation.

### What should be done in the future
- Seed the Vault secret paths, re-run the Kubernetes-auth bootstrap so the new service roles exist, and deploy both services live.

## Step 8: Use the live Vault root token path again, then bring PostgreSQL and Redis up end to end

The remaining live dependency was Vault. Both new services use the same Vault plus VSO path as MySQL, so the cluster cannot reconcile them fully until:

- Vault knows about the new Kubernetes-auth policies and roles
- the service-specific secret data exists at:
  - `kv/infra/postgres/cluster`
  - `kv/infra/redis/cluster`

I used the 1Password CLI again for that bootstrap step. The direct `op` flow was flaky earlier in the day, so I switched to a dedicated `tmux` session and verified `op vault list` there first. That kept the authenticated session stable long enough to read the Vault init note from the `Private` vault and extract the existing root token locally without changing the actual stored secret. Then I exported:

- `KUBECONFIG=/home/manuel/code/wesen/2026-03-27--hetzner-k3s/kubeconfig-91.98.46.169.yaml`
- `VAULT_ADDR=https://vault.yolo.scapegoat.dev`
- `VAULT_TOKEN=<root token from 1Password note>`

and ran:

- [`scripts/bootstrap-vault-kubernetes-auth.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-kubernetes-auth.sh)
- [`scripts/bootstrap-cluster-postgres-secrets.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-cluster-postgres-secrets.sh)
- [`scripts/bootstrap-cluster-redis-secrets.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-cluster-redis-secrets.sh)

That wrote the new Vault roles and seeded:

- PostgreSQL secret path with generated `postgres-password`, `postgres-db=platform`, `postgres-user=platform_admin`, and service coordinates
- Redis secret path with generated `redis-password` and service coordinates

After that I applied:

- [`gitops/applications/postgres.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/postgres.yaml)
- [`gitops/applications/redis.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/redis.yaml)

Argo created both namespaces immediately, VSO rendered:

- `postgres-auth`
- `redis-auth`

and both StatefulSets came up. I then ran the service-level acceptance checks:

- `kubectl wait --for=condition=ready pod/postgres-0 -n postgres --timeout=180s`
- `kubectl wait --for=condition=ready pod/redis-0 -n redis --timeout=180s`
- [`scripts/validate-cluster-postgres.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-cluster-postgres.sh)
- [`scripts/validate-cluster-redis.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-cluster-redis.sh)

Those validations proved:

- both Argo applications reached `Synced Healthy`
- PostgreSQL accepted SQL as `platform_admin` in database `platform`
- the PostgreSQL validation row survived a StatefulSet restart
- Redis accepted authenticated commands
- the Redis validation key survived a StatefulSet restart with AOF enabled

The Kubernetes events and logs also confirmed the expected local-path PVC creation and normal pod recreation during the scripted restart tests.

### What I did
- Switched to `op` inside a persistent `tmux` session to keep the authenticated 1Password session stable.
- Read the existing Vault init note from 1Password and used its root token to seed the live Vault configuration for the new services.
- Applied the PostgreSQL and Redis Argo applications.
- Waited for both pods to become ready.
- Ran the scripted persistence and auth validation for both services.

### Why
- The service manifests were already ready; the only missing live dependency was Vault data and auth configuration.
- Persistence across restart is the minimum acceptable proof for a shared single-node platform service.

### What worked
- The `tmux` workaround made the 1Password CLI reliable again for this session.
- VSO secret sync for both services was healthy immediately after the Vault bootstrap.
- Both PostgreSQL and Redis reached `Synced Healthy` without the chart-path failures that happened on the original MySQL attempt.
- The restart-and-persistence validation passed for both services.

### What didn't work
- My first attempt to sanitize the Vault note output was too narrowly written for a different label format, so I adjusted course and kept the actual bootstrap command non-echoing instead.
- The validation scripts were quiet while the restart tests ran, so I checked Argo state, pod state, events, and logs directly while waiting for the final success output.

### What I learned
- The MySQL-derived manifest pattern was the right long-term choice. Once the external chart dependency was gone, adding PostgreSQL and Redis became straightforward.
- For 1Password-backed operator workflows, a persistent shell session is more reliable than repeatedly spawning fresh CLI invocations.

### What should be done in the future
- Add backup, restore, engine-upgrade, and rollback procedures for all three shared services as the next platform-hardening slice.

### What should be done in the future
- Resume the CoinVault migration and replace its Coolify-only MySQL host with `mysql.mysql.svc.cluster.local`.

## Step 7: Scaffold shared PostgreSQL and Redis by directly reusing the proven MySQL pattern

With MySQL already live, I moved the umbrella ticket forward from “one service proven” to “reuse the same pattern for the next two services.” The important choice here was not to reopen the chart versus operator debate. MySQL had already answered that for this cluster. The right move was to generalize the pattern we now trust:

- repo-owned Kustomize manifests
- Argo CD application per service
- Vault Kubernetes auth policy and role per namespace/service account
- VSO-projected Kubernetes secret
- single-replica retained StatefulSet

I first updated the ticket itself so the work was no longer implicit. I added new PostgreSQL and Redis phases to `tasks.md`, updated the ticket index and plan to reflect that the deferral phase is over, and created a second design document focused on the follow-on service slices.

Then I added the actual implementation scaffold:

- Vault policies and roles:
  - [`vault/policies/kubernetes/postgres.hcl`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/postgres.hcl)
  - [`vault/roles/kubernetes/postgres.json`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/postgres.json)
  - [`vault/policies/kubernetes/redis.hcl`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/redis.hcl)
  - [`vault/roles/kubernetes/redis.json`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/redis.json)
- Vault secret bootstrap helpers:
  - [`scripts/bootstrap-cluster-postgres-secrets.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-cluster-postgres-secrets.sh)
  - [`scripts/bootstrap-cluster-redis-secrets.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-cluster-redis-secrets.sh)
- Validation helpers:
  - [`scripts/validate-cluster-postgres.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-cluster-postgres.sh)
  - [`scripts/validate-cluster-redis.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-cluster-redis.sh)
- Argo applications:
  - [`gitops/applications/postgres.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/postgres.yaml)
  - [`gitops/applications/redis.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/redis.yaml)
- New Kustomize packages:
  - [`gitops/kustomize/postgres/kustomization.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/postgres/kustomization.yaml)
  - [`gitops/kustomize/redis/kustomization.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/redis/kustomization.yaml)

The PostgreSQL service is intentionally conservative:

- namespace `postgres`
- service `postgres.postgres.svc.cluster.local:5432`
- database `platform`
- user `platform_admin`

Redis follows the same namespace-and-secret pattern, but it enables AOF persistence so restart behavior is meaningful and the service is not silently limited to “cache only” use cases.

Before touching the live cluster, I ran the local validation pass:

- `bash -n` over the four new helper scripts
- `kubectl kustomize gitops/kustomize/postgres`
- `kubectl kustomize gitops/kustomize/redis`
- `git diff --check`
- `docmgr doctor --ticket HK3S-0009 --stale-after 30`

Everything passed, which means the next step is no longer design work. It is live rollout: seed Vault, refresh the Vault Kubernetes auth bootstrap, apply the two Argo applications, and validate the services in-cluster.

### What I did
- Added the PostgreSQL and Redis task phases and a follow-on design doc.
- Added the Vault auth files, bootstrap scripts, validation scripts, Argo applications, and Kustomize packages.
- Validated the full scaffold locally.

### Why
- The MySQL slice already proved the platform pattern, so reusing it is lower risk than inventing a different one for Postgres or Redis.

### What worked
- The new service packages rendered cleanly on the first pass.
- The Vault auth and VSO pattern generalized cleanly from MySQL to both new services.

### What didn't work
- Nothing failed at this stage; this was a clean scaffold checkpoint.

### What I learned
- The MySQL slice paid off exactly the way it was supposed to: PostgreSQL and Redis are now incremental, not exploratory.

### What should be done in the future
- Commit the scaffold as its own checkpoint, then move into live Vault bootstrap and Argo rollout.

## Step 9: Add a real Hetzner Object Storage backup target, wire Vault/VSO delivery, and validate backup jobs for all three services

Once PostgreSQL, MySQL, and Redis were stable, the next real platform risk was obvious: the cluster had stateful services but no off-cluster backup target. I reused the existing Hetzner Object Storage Terraform pattern from the other Terraform repo slices instead of inventing a new storage control plane. That produced a new Terraform environment at [`storage/platform/k3s-backups/envs/prod`](/home/manuel/code/wesen/terraform/storage/platform/k3s-backups/envs/prod), and `terraform apply` created the private bucket `scapegoat-k3s-backups` with versioning enabled plus the service-prefix contract:

- `postgres/`
- `mysql/`
- `redis/`

The next step was wiring runtime delivery. I wrote the object-storage credentials into Vault at `kv/infra/backups/object-storage` using the new replayable ticket script [`01-seed-backup-object-storage-secret.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/01-seed-backup-object-storage-secret.sh), then extended the service Vault policies so the PostgreSQL, MySQL, and Redis service accounts could read that path. Each namespace got a matching `VaultStaticSecret` called `backup-storage`, and each Kustomize package got a CronJob:

- [`gitops/kustomize/postgres/backup-cronjob.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/postgres/backup-cronjob.yaml)
- [`gitops/kustomize/mysql/backup-cronjob.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/mysql/backup-cronjob.yaml)
- [`gitops/kustomize/redis/backup-cronjob.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/redis/backup-cronjob.yaml)

I deliberately stored the operational helpers in the ticket itself so the path is replayable later:

- [`00-common.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/00-common.sh)
- [`02-trigger-postgres-backup-job.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/02-trigger-postgres-backup-job.sh)
- [`03-trigger-mysql-backup-job.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/03-trigger-mysql-backup-job.sh)
- [`04-trigger-redis-backup-job.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/04-trigger-redis-backup-job.sh)
- [`05-list-backup-objects.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/05-list-backup-objects.sh)
- [`06-prune-backup-object.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/06-prune-backup-object.sh)

The PostgreSQL and Redis runs worked on the first attempt:

- PostgreSQL uploaded `postgres/postgres-20260329T162549Z.sql.gz`
- Redis uploaded `redis/redis-20260329T163605Z.tar.gz`

MySQL was the tricky one, and the exact failures matter because they changed the manifest design twice. The first backup job uploaded a 20-byte object because `mysqldump` failed with:

- `TLS/SSL error: self-signed certificate in certificate chain`

That revealed two problems:

- the client was trying to verify the in-cluster self-signed TLS chain
- the shell path was too optimistic because the dump pipeline still produced a tiny artifact

I first changed the job to dump to a real file and fail if the file was empty. That avoided silent success but surfaced the second runtime mismatch. Alpine’s MariaDB client could not authenticate against the MySQL 8 server because the server uses `caching_sha2_password`. The exact error was:

- `Plugin caching_sha2_password could not be loaded`

I then tried the MariaDB-compatible `--skip-ssl` path, but that still left the wrong client family in place. The final fix was to replace the one-off Alpine client with the official `mysql:8.4` image and install `awscli` there. That gave the CronJob the correct `mysqldump` binary for the live server and restored support for `--ssl-mode=DISABLED`.

After that change, the corrected MySQL backup completed and uploaded:

- `mysql/mysql-20260329T163525Z.sql.gz`

I then deleted the earlier invalid 20-byte object with [`06-prune-backup-object.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0009--add-cluster-level-postgres-mysql-and-redis-under-argo-cd/scripts/06-prune-backup-object.sh), leaving the bucket with one good artifact per service.

### What I did
- Added the Terraform-managed Hetzner Object Storage bucket and pushed it from the Terraform repo.
- Seeded `kv/infra/backups/object-storage` in Vault.
- Extended the PostgreSQL, MySQL, and Redis Vault policies plus VSO manifests.
- Added backup CronJobs for all three services and pushed them through Argo CD.
- Ran the PostgreSQL, MySQL, and Redis backup jobs manually.
- Listed the remote bucket contents and deleted the one invalid MySQL test artifact.

### Why
- The cluster already had real stateful services and needed an off-cluster recovery baseline before more applications land on top of them.

### What worked
- The shared Vault/VSO object-storage secret pattern generalized cleanly across all three services.
- PostgreSQL and Redis produced valid off-cluster artifacts on the first validation run.
- The final MySQL design using the official `mysql:8.4` image produced a valid 44.2 MiB dump artifact.

### What didn't work
- The first backup seeding script depended unnecessarily on `terraform output`, which failed outside the Terraform direnv context.
- The first MySQL backup path failed on self-signed TLS verification.
- The second MySQL backup path failed because Alpine's MariaDB client could not load the MySQL 8 auth plugin.

### What I learned
- For backup jobs, client binary compatibility matters just as much as service reachability.
- Ticket-local replay scripts immediately earn their keep because they force the operator path through the same sharp edges the documentation claims to handle.

### What should be done in the future
- Add full scratch restore drills for PostgreSQL, MySQL, and Redis instead of stopping at artifact creation.
- Add explicit retention rules and upgrade/rollback guidance for the scheduled backup path.

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
Summary: Chronological diary for introducing the first shared cluster data service on K3s, starting with MySQL.
LastUpdated: 2026-03-27T16:34:00-04:00
WhatFor: Use this to review the exact implementation trail for the MySQL-first cluster data-services slice.
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

### What should be done in the future
- Resume the CoinVault migration and replace its Coolify-only MySQL host with `mysql.mysql.svc.cluster.local`.

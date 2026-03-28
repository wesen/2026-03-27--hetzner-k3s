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

## Step 2: Turn the design into a real GitOps package and bootstrap toolchain

With the database-provisioning pattern decided, the next task was to stop talking abstractly about Keycloak and give the ticket a concrete package. I chose the same repo-owned manifest style that already succeeded for the shared MySQL, PostgreSQL, and Redis services, instead of reaching for a vendor chart. That keeps the runtime explicit and easier to debug.

The package now exists in:

- [`gitops/applications/keycloak.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/keycloak.yaml)
- [`gitops/kustomize/keycloak/kustomization.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/kustomization.yaml)

The important implementation choices I encoded were:

- parallel hostname: `auth.yolo.scapegoat.dev`
- official Keycloak image: `quay.io/keycloak/keycloak:26.1.0`
- shared PostgreSQL backing store at `postgres.postgres.svc.cluster.local:5432`
- two service accounts:
  - `keycloak`
  - `keycloak-db-bootstrap`
- Vault and VSO secret flow for:
  - runtime DB credential
  - bootstrap admin credential
  - PostgreSQL bootstrap credential for the Job
- an Argo `PreSync` Job that creates:
  - database `keycloak`
  - role `keycloak_app`

I also added the local helpers needed to seed and validate the deployment:

- [`scripts/bootstrap-keycloak-secrets.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-keycloak-secrets.sh)
- [`scripts/validate-keycloak.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-keycloak.sh)

The first validation pass was purely structural:

- `bash -n scripts/bootstrap-keycloak-secrets.sh`
- `bash -n scripts/validate-keycloak.sh`
- `kubectl kustomize gitops/kustomize/keycloak`
- `git diff --check`

That all passed. One small portability issue did show up while reviewing the rendered ConfigMap script: I had written the bootstrap shell with `set -euo pipefail` under `/bin/sh`. That is not the right assumption for the stock shell inside `postgres:16-alpine`, so I tightened it to `set -eu` and rewrote the database-existence check without relying on `pipefail`.

I also tried a server dry-run against the cluster:

- `kubectl apply --dry-run=server -f gitops/applications/keycloak.yaml`
- `kubectl apply --dry-run=server -k gitops/kustomize/keycloak`

The application manifest validated. The Kustomize package hit the expected namespace-not-found limitation of server dry-run because the target namespace does not exist yet and the dry-run does not stage earlier namespace creation for later objects. That is not a design problem; it is a known limitation of validating a package that creates its own namespace.

### What I did
- Chose repo-owned manifests and the parallel hostname.
- Added the Keycloak Argo application and Kustomize package.
- Added the Vault policies, roles, and bootstrap helpers.
- Added the PostgreSQL bootstrap `Job`.
- Added the initial deployment, service, and ingress.
- Fixed the bootstrap script portability issue before rollout.

### Why
- The repo-owned manifest path fits the rest of the cluster and avoids chart-induced surprises.
- The `PreSync` Job lets Argo own the database bootstrap without making the running Keycloak pod privileged.

### What worked
- The render and local static validation passed cleanly.
- The Vault policy split matched the intended service-account boundaries.
- The package structure now aligns with the rest of the cluster.

### What didn't work
- The first draft of the bootstrap shell was too optimistic about `pipefail` support under `/bin/sh`.
- Server-side dry-run could not fully validate namespaced objects before the namespace exists, which is expected but still worth recording.

### What I learned
- The parallel-host Keycloak rollout is now mostly an operator bootstrap problem, not a packaging problem.

### What should be done in the future
- Seed the Vault secret paths, re-run the Vault Kubernetes-auth bootstrap so the new roles exist, and deploy the Argo application.

## Step 3: Seed Vault, recover from a stuck Argo hook, and bring the parallel Keycloak live

Once the scaffold was committed, I moved into the live rollout. The first operational task was to seed Vault so the new package could actually reconcile:

- re-ran [`bootstrap-vault-kubernetes-auth.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-kubernetes-auth.sh) so the new `keycloak` and `keycloak-db-bootstrap` roles existed in the live Vault auth backend
- wrote the Keycloak runtime database secret and bootstrap-admin secret with [`bootstrap-keycloak-secrets.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-keycloak-secrets.sh)
- applied [`gitops/applications/keycloak.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/keycloak.yaml)

The Vault part worked immediately. The first Argo sync did not.

The bug was in the first version of the database bootstrap `Job`. I had made it an Argo `PreSync` hook, which sounds reasonable at first because the Keycloak database must exist before Keycloak starts. But hooks are executed outside the normal sync-wave ordering for the rest of the application. That meant Argo tried to create the hook Job before the service account and Vault/VSO resources existed. The job controller then produced:

- `pods "keycloak-db-bootstrap-" is forbidden: error looking up service account keycloak/keycloak-db-bootstrap: serviceaccount "keycloak-db-bootstrap" not found`

That left the application stuck in `operationState.phase=Running` while waiting forever on the failed hook.

The fix was:

1. change the bootstrap `Job` from a `PreSync` hook into a normal resource with:
   - `argocd.argoproj.io/sync-wave: "1"`
   - `argocd.argoproj.io/sync-options: Replace=true`
2. push that change
3. manually clean up the stale hook state:
   - delete the old job
   - remove the job hook finalizer
   - remove the stuck application finalizer
   - recreate the `Application`

Once the stale hook state was gone, the current revision synced correctly:

- namespace
- service accounts
- VaultConnection
- VaultAuth resources
- VaultStaticSecret resources
- bootstrap script ConfigMap
- database bootstrap Job
- service
- deployment
- ingress

The database bootstrap then succeeded, and the Keycloak pod came up. The initial Keycloak startup took a little longer because the container detected configuration changes and rebuilt the optimized server image on first boot. That was visible in the logs but not a failure.

The last small operational wrinkle was TLS timing. The first public `curl` check failed with:

- `curl: (60) SSL certificate problem: self-signed certificate`

That was just cert-manager’s temporary challenge certificate during ACME issuance. A short wait later, the certificate became:

- `certificate/keycloak-tls Ready=True`

and the full validation script passed:

- [`validate-keycloak.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-keycloak.sh)

That validation proved:

- Argo app `keycloak` is `Synced Healthy`
- the `keycloak` database exists
- the `keycloak_app` role exists
- the public hostname `https://auth.yolo.scapegoat.dev` is serving with a valid certificate
- the bootstrap-admin account can obtain a token against the public hostname

### What I did
- Seeded the live Vault data for Keycloak.
- Applied the Keycloak Argo application.
- Diagnosed the failed `PreSync` hook ordering bug.
- Changed the database bootstrap `Job` to a normal wave-ordered resource.
- Cleaned up the stale Argo hook and application finalizers.
- Recreated the application and completed the rollout.
- Waited for cert-manager to swap the temporary certificate for the final ACME certificate.
- Ran the end-to-end Keycloak validation script.

### Why
- The base runtime needed to be proven before touching realm/client migration.
- The rollout needed to preserve the external Keycloak as rollback, which is exactly what the parallel-host model accomplished.

### What worked
- Vault seeding and VSO secret sync worked immediately.
- The database bootstrap `Job` succeeded once it was allowed to run after its service account and secrets existed.
- The Keycloak deployment rolled out cleanly after the database contract existed.
- Public bootstrap-admin login validation succeeded.

### What didn't work
- The first `PreSync` hook design was wrong for a Job that depends on non-hook resources in the same application.
- The stuck hook left stale Argo state behind, so I had to clear finalizers manually before the corrected revision could take over.
- The first public validation hit the expected temporary self-signed certificate before ACME finished.

### What I learned
- For this repo, the right pattern is a normal wave-ordered bootstrap `Job`, not a `PreSync` hook, when the Job depends on Vault/VSO and service-account resources from the same package.
- Clearing stale Argo hook state can be necessary even after the manifest bug is fixed; Git alone does not always unwind a wedged operation state.

### What should be done in the future
- Create the Terraform-side parallel environment for recreating the `infra` realm and clients against `auth.yolo.scapegoat.dev`.
- Validate Vault operator login against the new Keycloak instance.
- Validate at least one application login flow against the new Keycloak instance.

## Step 4: Recreate the `infra` realm in the new Keycloak and repoint Vault OIDC

After the base runtime was healthy, I moved to the first true migration task: recreate the shared `infra` realm and the `vault-oidc` client against the new Keycloak instance without touching the old external one. I did that in the Terraform repo by cloning the hosted `infra-access` environment into a new `k3s-parallel` environment and pointing it at `https://auth.yolo.scapegoat.dev`.

That apply succeeded and left behind the expected realm/client shape on the K3s Keycloak:

- realm `infra`
- groups `infra-admins` and `infra-readonly`
- GitHub identity provider
- confidential browser client `vault-oidc`
- group membership mapper for the `groups` claim

With that in place, I reconfigured Vault itself. I chose the pragmatic path and repointed the existing `oidc/` mount at the new issuer instead of creating a second temporary Vault auth mount. That kept the validation focused on the real production operator path and avoided extra callback/client drift. The bootstrap and validation helpers both passed after I corrected the 1Password note parsing for the Vault root token.

The resulting live Vault config now reads:

- `oidc_discovery_url = https://auth.yolo.scapegoat.dev/realms/infra`
- `oidc_client_id = vault-oidc`
- `default_role = operators`

### What I did
- Added and applied the Terraform `k3s-parallel` environment for `infra-access`.
- Reused the existing `vault-oidc` client model against the new Keycloak hostname.
- Repointed Vault `oidc/` at `https://auth.yolo.scapegoat.dev/realms/infra`.
- Re-ran [`bootstrap-vault-oidc.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-oidc.sh) and [`validate-vault-oidc-config.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-vault-oidc-config.sh).

### Why
- This is the smallest real proof that the in-cluster Keycloak can replace the external one for operator auth.
- A parallel Vault auth mount would have reduced risk slightly, but it also would have validated a path the team does not actually intend to operate.

### What worked
- Terraform recreated the `infra` realm cleanly on the new Keycloak instance.
- The `vault-oidc` callback URI was already valid for `vault.yolo.scapegoat.dev`.
- Vault OIDC bootstrap and config validation passed once the correct client secret and root token parsing were in place.

### What didn't work
- My first root-token extraction assumed a single-line `key: value` note format in 1Password.
- The actual note stores `Root token:` on one line and the token on the next line, so the first bootstrap rerun failed with `missing required environment variable: VAULT_TOKEN`.

### What I learned
- The new Keycloak instance is no longer just “up.” It is actually serving the operator OIDC contract that matters.
- The remaining migration risk has moved from platform wiring to human workflow and cutover timing.

## Step 5: Prove browser login and validate logical backup/restore

Once Vault was pointed at the new issuer, I wanted proof that real humans could still use it and that the new identity plane had a credible recovery path. I created a temporary local user in the `infra` realm, added it to `infra-admins`, and used that account for browser-based smoke tests.

The first browser flow was Vault itself. I logged out of the existing Vault UI session, started a fresh OIDC sign-in, authenticated against `auth.yolo.scapegoat.dev`, completed the required profile fields on first login, and landed back on the Vault dashboard. That proved the real Vault popup flow against the new Keycloak issuer, not just the raw OIDC config shape.

For a second browser-backed proof, I opened the Keycloak Account Console on:

- `https://auth.yolo.scapegoat.dev/realms/infra/account/`

and confirmed the same temporary user could sign in and load the realm-backed account UI. That is a meaningful second path even though it is realm-native rather than an already-migrated external application client.

I then turned to the backup/restore task. Instead of leaving that as a theoretical runbook, I wrote [`validate-keycloak-backup-restore.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-keycloak-backup-restore.sh) and ran it live. The script:

1. reads the shared PostgreSQL admin credential synced into `keycloak-postgres-admin`
2. creates a scratch database `keycloak_restore_smoke`
3. runs `pg_dump` against the live `keycloak` database
4. restores that dump into the scratch database
5. checks that the restored database contains:
   - realm `infra`
   - client `vault-oidc`
6. drops the scratch database on cleanup

The live run passed with:

- `keycloak backup/restore validation passed`
- `verified realm: infra`
- `verified client: vault-oidc`

After the smoke tests, I deleted the temporary validation user so it would not linger as accidental operator state.

### What I did
- Created a temporary `infra-admins` user in the new Keycloak realm.
- Validated real browser login to Vault through the new issuer.
- Validated browser login to the Keycloak Account Console.
- Added and ran [`validate-keycloak-backup-restore.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-keycloak-backup-restore.sh).
- Deleted the temporary validation user afterward.

### Why
- HK3S-0008 should not claim success on config alone.
- Browser login proves the operator workflow.
- Logical dump/restore proves that realm and client data can be recovered from the shared PostgreSQL backing store.

### What worked
- Vault browser login landed on the dashboard after OIDC through `auth.yolo.scapegoat.dev`.
- The Keycloak Account Console loaded successfully for the `infra` realm.
- The dump/restore script successfully reconstructed the `infra` realm and `vault-oidc` client in a scratch database.

### What didn't work
- The first login of a brand-new local Keycloak user required the profile-completion screen before redirecting back to Vault. That was expected behavior, but it lengthened the browser validation slightly.

### What I learned
- The current parallel slice is operationally convincing: human auth works, shared PostgreSQL works, and backup/restore is no longer hypothetical.
- The external deployment is now a rollback choice, not a technical dependency.

### What should be done in the future
- Decide whether to migrate any non-`infra` realms, such as application-specific clients and brokers, into the K3s Keycloak.
- Decide whether to cut over `auth.scapegoat.dev` or keep the external deployment as a long-lived separate control plane.

## Step 6: Migrate CoinVault to the new Keycloak and retire the demo stack

With the `infra` slice proven, I moved one real application realm over: `coinvault`. That was the right next test because CoinVault is already live on K3s and exercises the exact browser OIDC path we care about operationally.

I started in the Terraform repo by cloning the hosted `keycloak/apps/coinvault/envs/hosted` environment into a new `k3s-parallel` environment aimed at `https://auth.yolo.scapegoat.dev`. The first local apply looked successful, but the resulting issuer was wrong:

- `https://auth.yolo.scapegoat.dev/realms/smailnail`

That turned out to be a local input leak. A preexisting environment value was still setting `realm_name=smailnail`, so the first apply created the wrong realm even though the module and example files said `coinvault`. I caught it immediately because the new CoinVault pod crashed on startup with:

- `create oidc authenticator: oidc discovery request failed with status 404`

and the public well-known discovery URL for `coinvault` returned 404.

The fix was to rewrite the local ignored `terraform.tfvars` for the `k3s-parallel` environment with explicit:

- `realm_name = "coinvault"`
- `realm_display_name = "coinvault"`

then re-run `terraform plan` and `terraform apply`. Terraform replaced the accidental `smailnail` realm and recreated the intended `coinvault` realm plus the `coinvault-web` client. After that, this URL returned the expected discovery document:

- `https://auth.yolo.scapegoat.dev/realms/coinvault/.well-known/openid-configuration`

Once the Keycloak side was real, I updated the K3s CoinVault package:

- [`gitops/kustomize/coinvault/deployment.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/deployment.yaml)
- [`gitops/kustomize/coinvault/mysql-ide-deployment.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml)

Both now point at:

- `https://auth.yolo.scapegoat.dev/realms/coinvault`

I also updated [`seed-coinvault-k3s-vault-secrets.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/seed-coinvault-k3s-vault-secrets.sh) so the Vault-backed runtime secret can override `oidc_issuer_url` cleanly, and then re-seeded the K3s Vault secret with the new issuer value. That kept the synced runtime secret and the pod env consistent.

The first CoinVault rollout after the manifest flip still failed, but for a now-obvious reason: the pod had started during the brief window where the wrong realm existed, so it cached the bad 404 outcome and sat in `CrashLoopBackOff`. Deleting that bad pod after the corrected realm existed was enough. The new pod came up cleanly, Argo finished wave 1, and `mysql-ide` then rolled forward in wave 2 to the same issuer.

The real proof was browser login. I created a temporary local user in the `coinvault` realm, opened:

- `https://coinvault.yolo.scapegoat.dev/auth/logout`

which redirected to the new Keycloak login page at:

- `https://auth.yolo.scapegoat.dev/realms/coinvault/...`

Then I authenticated with the temporary user and landed back in the authenticated CoinVault UI. That is the first real external application login against the in-cluster Keycloak, not just a realm-native console or Vault operator path.

With CoinVault stable, I removed the old placeholder workload:

- deleted the live Argo `Application` for `demo-stack`
- waited for the `demo` namespace to enter normal finalizer cleanup and disappear
- deleted:
  - [`gitops/applications/demo-stack.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/demo-stack.yaml)
  - the entire [`gitops/kustomize/demo-stack`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/demo-stack) package

That leaves the cluster with a real app using the new Keycloak, instead of the original placeholder demo package.

Rollback remains simple and explicit:

1. keep the external `auth.scapegoat.dev` deployment online
2. revert the CoinVault issuer URLs in the K3s manifests
3. re-seed the Vault-backed CoinVault runtime secret with the old issuer
4. let Argo roll the deployments back

No database migration is needed for that rollback because this slice only changed OIDC issuer and client source, not CoinVault application data.

### What I did
- Added the Terraform `k3s-parallel` environment for the `coinvault` realm.
- Corrected an accidental first apply that created `smailnail` instead of `coinvault`.
- Recreated the `coinvault` realm and `coinvault-web` client against the new Keycloak.
- Updated CoinVault and MySQL IDE to use the new issuer.
- Re-seeded the Vault-backed runtime secret with the new issuer metadata.
- Validated real browser login through CoinVault against the new issuer.
- Removed the old `demo-stack` application from the cluster and from Git.

### Why
- A Keycloak migration is not credible until a real external app uses it.
- CoinVault is the right first app because it is already live, already OIDC-backed, and already business-relevant.
- Removing `demo-stack` prevents a dead placeholder from obscuring the fact that the cluster now carries real workloads.

### What worked
- The corrected `coinvault` realm published a valid discovery document.
- CoinVault rolled successfully once the bad pod from the 404 window was replaced.
- MySQL IDE followed in the next Argo sync wave.
- Browser login landed back in the authenticated CoinVault UI.
- The demo stack pruned cleanly from the cluster and its namespace disappeared.

### What didn't work
- The first Terraform apply created the wrong realm because a stale input value leaked in locally.
- The first CoinVault rollout happened during that bad-realm window and crashed until the pod was recreated.

### What I learned
- The right migration pattern is still “parallel realm, then flip app issuer, then validate browser flow.” The failed first apply did not invalidate the pattern; it just showed why explicit local inputs matter.
- Removing placeholder apps as soon as a real one exists makes the cluster state much easier to read.

### What should be done in the future
- Decide whether other shared application realms should also move to the in-cluster Keycloak.
- Decide whether `auth.scapegoat.dev` should ever cut over to the K3s instance or remain the long-lived external rollback boundary.

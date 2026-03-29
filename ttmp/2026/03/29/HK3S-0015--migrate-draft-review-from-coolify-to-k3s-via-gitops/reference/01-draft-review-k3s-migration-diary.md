---
Title: Draft Review K3s migration diary
Ticket: HK3S-0015
Status: active
Topics:
    - draft-review
    - k3s
    - gitops
    - keycloak
    - postgres
    - ghcr
    - vault
DocType: reference
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: Chronological diary for the Draft Review migration work.
LastUpdated: 2026-03-29T11:05:00-04:00
WhatFor: Preserve the real implementation trail for the migration.
WhenToUse: Use when reviewing what was done, in what order, and why.
---

# Draft Review K3s migration diary

## 2026-03-29: Ticket opened and current runtime shape inspected

I started by reading the existing hosted deployment docs instead of guessing the runtime contract from memory.

Important findings from the current Coolify deployment:

- public URL is `https://draft-review.app.scapegoat.dev`
- OIDC issuer is `https://auth.scapegoat.dev/realms/draft-review`
- the backend process is `draft-review serve`
- the app needs PostgreSQL plus persistent media storage
- hosted Keycloak config is already managed in Terraform at `keycloak/apps/draft-review/envs/hosted`

Important findings from the source repo:

- the production `Dockerfile` already builds the frontend and embeds it into the Go binary
- there is no GitHub Actions packaging path yet
- there is no `deploy/gitops-targets.json` yet
- the repo is private and currently only documents the Coolify deployment path

That makes Draft Review a good test of the full private-app migration path:

- private GHCR image
- private-image pull secret
- shared Postgres database bootstrap
- K3s Keycloak parallel realm/client
- PVC-backed media directory

## 2026-03-29: Source-repo packaging scaffold implemented

The first real implementation slice was the source-repo packaging layer. I deliberately kept this separate from cluster manifests so the release path could be validated in isolation.

Changes made in `/home/manuel/code/wesen/2026-03-24--draft-review`:

- added `.github/workflows/publish-image.yaml`
- added `deploy/gitops-targets.json`
- added `scripts/open_gitops_pr.py`
- updated `README.md` to describe the new GHCR and GitOps PR model

Validation performed:

```bash
go test ./cmd/... ./pkg/... -count=1
docker build -t draft-review:local .
python3 scripts/open_gitops_pr.py --help
```

Observed result:

- Go tests passed
- the production Docker image built successfully, including the frontend embed step
- the PR updater script is executable and exposes the expected CLI

Important implementation note:

- the source repo has many unrelated untracked files already present locally
- only the new packaging files and README changes should be committed for this task

Important operational note:

- the `gitops-pr` workflow is designed to skip cleanly when `GITOPS_PR_TOKEN` is not configured
- that means this packaging task can be merged before the K3s target manifest exists, without breaking the repository’s default workflow behavior

## 2026-03-29: Parallel Keycloak env created and applied

The next prerequisite was identity. I created a new Terraform env at:

- `/home/manuel/code/wesen/terraform/keycloak/apps/draft-review/envs/k3s-parallel`

The env shape intentionally matches the existing hosted env, but with:

- a different backend state key
- the K3s Keycloak base URL
- the parallel public app URL:
  - `https://draft-review.yolo.scapegoat.dev`

First apply attempt failed before planning the Keycloak resources:

```text
Error refreshing state: Unable to access object ... in S3 bucket ... 403 Forbidden
```

That was not a Keycloak problem. It was the shared Terraform backend requiring the correct AWS profile. Re-running with:

```bash
AWS_PROFILE=manuel terraform init
AWS_PROFILE=manuel terraform validate
AWS_PROFILE=manuel terraform apply -auto-approve
```

resolved the backend access issue and the actual Keycloak apply succeeded.

Observed result:

- realm `draft-review` created
- client `draft-review-web` created
- callback output:
  - `https://draft-review.yolo.scapegoat.dev/auth/callback`

This is an important checkpoint because the K3s application deployment can now target the in-cluster issuer without touching the old hosted realm/client.

## 2026-03-29: K3s package scaffold rendered cleanly before first cluster commit

Before committing any K3s-side manifests, I stopped to validate two assumptions that would otherwise create noisy follow-up debugging:

- the package should render successfully through `kubectl kustomize`
- the image tag referenced by the first deployment manifest should already exist in GHCR

I verified the new package render from the K3s repo with:

```bash
KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml \
  kubectl kustomize gitops/kustomize/draft-review >/tmp/draft-review-kustomize.yaml
```

Observed result:

- the render succeeded with no Kustomize or schema errors

I then checked the Draft Review source-repo workflow status through GitHub CLI. The relevant published run was:

- workflow: `publish-image.yaml`
- run id: `23711624183`
- conclusion: `success`

That means the first image tag now exists at:

- `ghcr.io/wesen/2026-03-24--draft-review:sha-125c36e`

This matters because the first K3s deployment commit now points at a real immutable artifact instead of relying on a not-yet-published image or a local node import bridge.

I also re-read the current hosted deployment docs to confirm the scaffold still matches the real runtime contract:

- OIDC mode stays enabled
- session secret and session TTL settings remain required
- the app still needs PostgreSQL plus persistent media storage
- the new parallel issuer/redirect pair should be:
  - `https://auth.yolo.scapegoat.dev/realms/draft-review`
  - `https://draft-review.yolo.scapegoat.dev/auth/callback`

This was the right moment to checkpoint the K3s scaffold because the migration no longer depends on guesses for the runtime contract or the image supply chain.

## 2026-03-29: First live rollout exposed a missing platform `ClusterIssuer`

After the K3s scaffold was committed and pushed, I bootstrapped Vault Kubernetes auth, seeded the Draft Review runtime secret, and seeded the private GHCR image-pull secret from Vault. That part worked as expected:

- `draft-review-runtime` synced into the namespace
- `draft-review-ghcr-pull` was created as `kubernetes.io/dockerconfigjson`
- the database bootstrap Job succeeded
- the app Deployment pulled the private GHCR image and became `Ready`

The app log showed the expected runtime contract:

- OIDC issuer: `https://auth.yolo.scapegoat.dev/realms/draft-review`
- auth mode: `oidc`
- database configured: `true`
- media root: `/data/media`

The first validation failure was not application health. It was TLS. The validation script hit:

```text
curl: (60) SSL certificate problem: self-signed certificate
```

I traced that through cert-manager instead of assuming the app ingress was wrong.

Observed cluster state:

- `CertificateRequest/draft-review-tls-1` existed
- `Certificate/draft-review-tls` existed
- no `Order` or `Challenge` resources were created
- `kubectl get clusterissuer` returned **no resources found**

The critical evidence was the certificate request status:

```text
Referenced "ClusterIssuer" not found: clusterissuer.cert-manager.io "letsencrypt-prod" not found
```

That means Draft Review did not introduce a bad issuer name. It exposed a broader platform drift:

- the cluster no longer had any live `ClusterIssuer` resources
- older apps still looked healthy because their TLS secrets already existed from earlier issuance
- new apps could only fall back to Traefik's self-signed default cert

This changed the migration plan in an important way. Restoring ACME issuance should not be treated as a Draft Review one-off fix. It belongs in the platform baseline. I therefore added a dedicated GitOps-managed platform app to own:

- `ClusterIssuer/letsencrypt-prod`

so future apps do not depend on an old demo-stack bootstrap artifact or a manually recreated issuer.

## 2026-03-29: Hosted Draft Review DB and author identity analyzed for migration

After the K3s app itself was healthy, I switched to the remaining state-migration question: existing content plus the real Manuel author account.

I inspected the application auth code first, because the right migration depends on how Draft Review resolves authors after OIDC login.

Important findings from the code:

- the app looks up existing users by:
  - `auth_issuer`
  - `auth_subject`
- only if no row matches that pair does it fall back to creating or upserting by email

That means the database migration cannot rely on email alone. If I import the old DB unchanged, the existing Manuel row will still point at the **old** Keycloak issuer and **old** subject UUID, so K3s login will not bind back to it automatically.

I then inspected the old Coolify-hosted Postgres container directly on the old host:

- host: `89.167.52.236`
- Postgres container: `go1o5tbegalwy3kesshq3hcp`
- database: `draft_review`

The hosted `users` table currently contains exactly two rows:

- `wesen@ruinwesen.com`
  - name: `Manuel Odendahl`
  - issuer: `https://auth.scapegoat.dev/realms/draft-review`
  - subject: `ad1655b1-91ad-4b0b-8200-b33b8526244a`
- `author@example.com`
  - name: `Draft Author`
  - issuer: `https://auth.scapegoat.dev/realms/draft-review`
  - subject: `3a0357ef-9917-4cd7-9739-613ae23cc94b`

I also verified that the hosted database schema is not fully current:

- there is no `article_assets` table yet in the hosted DB

That rules out a naive full schema restore into K3s. The safer route is:

1. keep the current K3s target schema
2. import the hosted data into it
3. create a Terraform-managed `wesen` user in the K3s Keycloak realm
4. rewrite the imported Manuel row to the new issuer and new subject

I wrote that up as a dedicated ticket document:

- `design/02-draft-review-data-and-author-identity-migration-plan.md`

and expanded the task list so the remaining Draft Review work is now explicit instead of implicit.

## 2026-03-29: Terraform-managed `wesen` user created in the K3s Draft Review realm

I resumed the migration by finishing the identity side first, because the Draft Review user row rewrite needs a real target issuer and a real target subject UUID. Without that, the database migration would still be guessing at the future login identity.

I reused the existing Keycloak Terraform pattern from the repo's local fixtures module instead of inventing a new resource shape. The Draft Review parallel env now creates:

- `keycloak_user.wesen`

with:

- username `wesen`
- email `wesen@ruinwesen.com`
- first name `Manuel`
- last name `Odendahl`
- non-temporary initial password from local `terraform.tfvars`

I extended the env files at:

- `keycloak/apps/draft-review/envs/k3s-parallel/main.tf`
- `keycloak/apps/draft-review/envs/k3s-parallel/variables.tf`
- `keycloak/apps/draft-review/envs/k3s-parallel/outputs.tf`
- `keycloak/apps/draft-review/envs/k3s-parallel/terraform.tfvars.example`

Then I generated a password locally, added it to the uncommitted `terraform.tfvars`, and applied the env with:

```bash
AWS_PROFILE=manuel terraform -chdir=keycloak/apps/draft-review/envs/k3s-parallel validate
AWS_PROFILE=manuel terraform -chdir=keycloak/apps/draft-review/envs/k3s-parallel apply -auto-approve
```

That succeeded cleanly and returned the new K3s Keycloak subject:

- `e0dfdba3-69f8-4b72-8033-d03c958af720`

I immediately stored the generated password in 1Password so the credential does not remain stranded in local Terraform state as the only recoverable copy. The item is:

- `draft-review yolo k3s wesen keycloak user 2026-03-29`

This completes the identity prerequisite for the DB migration. The next step is now purely data-side:

1. export the hosted Draft Review DB with ticket-local scripts
2. snapshot the target K3s DB before import
3. import the hosted rows into the cluster DB
4. rewrite the imported Manuel row from:
   - issuer `https://auth.scapegoat.dev/realms/draft-review`
   - subject `ad1655b1-91ad-4b0b-8200-b33b8526244a`
   to:
   - issuer `https://auth.yolo.scapegoat.dev/realms/draft-review`
   - subject `e0dfdba3-69f8-4b72-8033-d03c958af720`

## 2026-03-29: Ticket-local migration scripts standardized and the hosted Draft Review data was imported

Before I continued with the database move, I normalized the ticket script inventory so the whole migration could be replayed later from the ticket itself instead of from shell history fragments. The ticket `scripts/` folder now uses an ordered naming scheme:

- `00-common.sh`
- `01-seed-draft-review-vault-secrets.sh`
- `02-validate-draft-review-k3s.sh`
- `03-export-hosted-draft-review-db.sh`
- `04-snapshot-k3s-draft-review-db.sh`
- `05-import-draft-review-data-into-k3s.sh`
- `06-rewrite-draft-review-wesen-identity.sh`
- `07-validate-draft-review-data-migration.sh`

That was not just cosmetic. While executing the real import, those scripts became the exact record of what worked and what broke.

The first source export succeeded, but replay into the cluster failed immediately on:

```text
ERROR:  unrecognized configuration parameter "transaction_timeout"
```

I inspected the dump header and found PostgreSQL 18 client drift in the export artifact:

- `SET transaction_timeout = 0;`
- `\restrict`
- `\unrestrict`

I fixed that in the export and snapshot scripts so future reruns normalize the dump automatically instead of relying on a hand-edited file.

Once that was fixed, the restore advanced further but then failed on the circular `articles` / `article_versions` relationship, which matched the earlier `pg_dump` warning. I changed the import script to replay with:

- `SET session_replication_role = replica;`

for the replay window only.

The next real failure was source-schema drift:

```text
column "body_plaintext" of relation "article_sections" does not exist
```

The hosted `article_sections` table still had `body_plaintext`, but the target K3s schema no longer does. I replaced the brittle line-by-line SQL rewrite attempt with a cleaner export strategy:

- skip the hosted `article_sections` block from `pg_dump`
- append a custom SQL export for `article_sections` that emits only the target columns

After that, another operational issue appeared: streaming the whole SQL replay through `kubectl exec -i` caused a connection reset and only partially imported the data. I made the import script more reliable by:

- wrapping the SQL locally
- copying it into the Postgres pod with `kubectl cp`
- running `psql -f` inside the pod

That completed cleanly.

The final durable counts in the K3s `draft_review` database now match the hosted source:

- `article_reaction_types = 16`
- `article_sections = 4`
- `article_versions = 4`
- `articles = 4`
- `default_reaction_types = 4`
- `reactions = 34`
- `reader_invites = 8`
- `review_paragraph_progress = 3`
- `review_section_progress = 3`
- `review_summaries = 3`
- `users = 2`

I then ran the identity rewrite script, which updated the imported Manuel row to:

- issuer `https://auth.yolo.scapegoat.dev/realms/draft-review`
- subject `e0dfdba3-69f8-4b72-8033-d03c958af720`

## 2026-03-29: Browser login validated imported Draft Review ownership on K3s

Database counts alone were not enough. The ticket task required proof that the K3s app actually resolves the imported Manuel content under the new K3s Keycloak identity.

I finished that with a real browser login through the K3s Keycloak realm:

- opened `https://draft-review.yolo.scapegoat.dev`
- clicked `Sign In With Keycloak`
- logged in as `wesen`
- returned to the Draft Review UI on K3s

The post-login UI showed:

- header identity `Manuel Odendahl`
- two author-owned draft articles in the left article list
- one of the imported Manuel drafts opened in the detail pane
- section title `Claude feeling dumb? Time to do some engineering.`

That matters because the hosted source database has four total articles but only two belong to Manuel. Seeing exactly those two after the issuer/subject rewrite is strong proof that:

- the imported user row is binding to the new Keycloak subject correctly
- article ownership is preserved
- the K3s Draft Review app is serving the migrated user state correctly

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

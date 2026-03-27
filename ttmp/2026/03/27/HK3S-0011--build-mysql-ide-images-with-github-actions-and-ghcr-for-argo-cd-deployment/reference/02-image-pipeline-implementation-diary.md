---
Title: Image pipeline implementation diary
Ticket: HK3S-0011
Status: active
Topics:
    - coinvault
    - k3s
    - gitops
    - github
    - ghcr
    - ci-cd
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml
      Note: Workflow implementation will be recorded here once created
    - Path: /home/manuel/code/wesen/2026-03-27--mysql-ide/Dockerfile
      Note: Container build input may need workflow-aligned metadata changes
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml
      Note: Deployment cutover from node-local images to GHCR will be recorded here
ExternalSources: []
Summary: Chronological implementation diary for the GitHub Actions, GHCR, and Argo CD rollout work in HK3S-0011.
LastUpdated: 2026-03-27T18:09:00-04:00
WhatFor: Capture the real implementation sequence, exact commands, validation results, and failures while moving mysql-ide to a registry-backed image path.
WhenToUse: Read this when reviewing or continuing the HK3S-0011 implementation work.
---

# Image pipeline implementation diary

## Goal

Record the exact implementation trail for moving `mysql-ide` from manual node-local image import to GitHub Actions builds, GHCR image storage, and registry-backed Argo CD deployment.

## Step 1: turn the design ticket into an execution checklist and re-check the live baseline

Before writing any workflow code, I converted the ticket’s placeholder “future implementation tasks” into a real execution plan. That mattered because there are now two different repos and two different kinds of rollout risk:

- the app repo can fail in CI or publish the wrong image
- the K3s repo can point the cluster at an image tag that does not exist or cannot be pulled

I also re-checked the current baseline so the diary would start from facts instead of memory:

- the K3s deployment still points at `mysql-ide:hk3s-0010`
- the pull policy is still `Never`
- the app repo now has a real GitHub remote
- the app repo still has no `.github/workflows/`

### What I did

- Read:
  - [tasks.md](../tasks.md)
  - [mysql-ide-deployment.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml)
  - [kustomization.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/kustomization.yaml)
  - [README.md](/home/manuel/code/wesen/2026-03-27--mysql-ide/README.md)
- Checked:
  - `git remote -v`
  - `gh auth status`
  - `gh repo view ...`
  - `gh api repos/.../actions/permissions`

### What I learned

- GitHub-side prerequisites are now good enough to implement the workflow directly.
- The cleanest rollout remains: app repo first, cluster repo second.

### What should happen next

- create the workflow and supporting docs in the app repo
- validate locally before pushing
- push and watch the first GitHub Actions publish run

## Step 2: implement the app-repo workflow and validate it locally

With the baseline documented, I moved into the first actual implementation slice in `/home/manuel/code/wesen/2026-03-27--mysql-ide`. The goal of this slice was to make the app repo self-describing and CI-ready before involving GitHub or the cluster.

I added a new workflow at:

- [/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml](/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml)

The workflow does three things:

- validates PRs by running tests and building the image
- publishes on `main`
- exposes `workflow_dispatch` for manual retries

I also updated:

- [/home/manuel/code/wesen/2026-03-27--mysql-ide/Dockerfile](/home/manuel/code/wesen/2026-03-27--mysql-ide/Dockerfile)
- [/home/manuel/code/wesen/2026-03-27--mysql-ide/README.md](/home/manuel/code/wesen/2026-03-27--mysql-ide/README.md)

The Dockerfile now carries OCI labels that point back to the GitHub source repository, and the README now explains the intended GHCR-backed release path rather than treating node-local import as the normal deployment story.

### What I did

- Added the workflow file.
- Added OCI labels to the runtime image.
- Documented the GitHub Actions plus GHCR path in the app README.
- Ran:
  - `go test ./...`
  - `docker build -t mysql-ide:gha-test .`

### What worked

- `go test ./...` passed cleanly.
- `docker build -t mysql-ide:gha-test .` succeeded.
- The repo is now in a state where pushing `main` should trigger a real publish attempt.

### What should happen next

- commit the app-repo workflow slice
- push to `main`
- watch the first workflow run
- verify the first GHCR image and package visibility behavior

## Step 3: publish the first image, remove the Node 20 warning, and confirm GHCR pullability

Once the workflow was committed, I pushed the app repo to `main` and watched the first `publish-image` run on GitHub.

Important run:

- `23669507246`
- commit:
  - `5c7a77dc431cb4cfa03664ec753dd21b2206ea44`

That first run succeeded and published the image, which proved the core design:

- GitHub Actions can build the image
- `GITHUB_TOKEN` can publish it to GHCR
- the package appears under:
  - `ghcr.io/wesen/2026-03-27--mysql-ide`

The first run also surfaced a real maintenance issue: GitHub emitted a deprecation warning because several of the action versions were still running on Node 20. Rather than leave that as a vague future problem, I queried the current action releases and found newer majors:

- `actions/setup-go` -> `v6`
- `docker/setup-buildx-action` -> `v4`
- `docker/metadata-action` -> `v6`
- `docker/login-action` -> `v4`
- `docker/build-push-action` -> `v7`

I updated the workflow immediately, committed again, pushed again, and watched the second run:

- `23669600578`
- commit:
  - `2c3003f420d29a5a1a8f6c895f0ee9b319e3c24f`

That second run succeeded with the newer action versions and became the clean image source for the cluster cutover.

### What I did

- Pushed the workflow commit to `main`.
- Watched the first publish run to success.
- Inspected the deprecation warning.
- Queried current upstream action releases with `gh release view`.
- Updated the workflow to current major versions.
- Pushed the second workflow commit.
- Watched the second publish run to success.
- Confirmed the new tag was pullable anonymously:
  - `docker pull ghcr.io/wesen/2026-03-27--mysql-ide:sha-2c3003f`

### What worked

- GHCR publishing worked on the first attempt.
- The package was publicly pullable, which meant no `imagePullSecret` was needed for the cluster cutover.
- The workflow could be upgraded immediately to remove the deprecation warning.

### What was tricky

- The first passing pipeline was not yet the one I wanted to leave behind because of the Node 20 warning.
- It was worth paying the cost of one more push so the cluster would cut over to a cleaner workflow output.

### What should happen next

- switch the K3s manifest to the GHCR tag from the second successful run
- let Argo reconcile the new image source
- verify the live pod image and UI behavior

## Step 4: cut the cluster over to GHCR and verify the live app

With the new image tag published and pullable, I changed the K3s deployment in:

- [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml)

The two meaningful changes were:

- `image: ghcr.io/wesen/2026-03-27--mysql-ide:sha-2c3003f`
- `imagePullPolicy: IfNotPresent`

That is the actual end of the old node-local runtime path. The old import script can still exist as a fallback tool, but it is no longer required for normal deployment.

I validated the manifest locally with:

- `kubectl kustomize gitops/kustomize/coinvault`
- `kubectl apply --dry-run=server -k gitops/kustomize/coinvault`

Then I committed and pushed the K3s repo change:

- `bdf7294`

The first Argo status check was slightly misleading: the application still reported `Synced Healthy`, but it was synced against the previous revision `8ec0949`, not the new deployment commit. I confirmed that by reading:

- `.status.sync.revision`

Then I forced a hard refresh:

- `kubectl -n argocd annotate application coinvault argocd.argoproj.io/refresh=hard --overwrite`

After that, Argo reconciled to:

- `bdf72947154604d295cd8eb129a41d59ac013e1b`

and the deployment rolled to the new GHCR image successfully.

### What I did

- Updated the manifest.
- Ran local Kustomize render and server-side dry-run validation.
- Committed and pushed the K3s manifest change.
- Forced an Argo hard refresh when it stayed on the previous revision.
- Waited for the rollout to complete.
- Verified:
  - Deployment template image
  - Pod image
  - image digest
  - Argo sync and health
  - `/healthz`

### What worked

- The cluster pulled the public GHCR image successfully.
- The pod rolled from:
  - `mysql-ide:hk3s-0010`
  to:
  - `ghcr.io/wesen/2026-03-27--mysql-ide:sha-2c3003f`
- Argo ended in `Synced Healthy`.
- `/healthz` still returned the expected auth and DB contract.

### What was tricky

- Argo’s first post-push status was healthy but stale because it had not refreshed to the latest revision yet.
- The correct fix was a hard refresh, not changing the manifest again.

### What should happen next

- re-run an authenticated browser check against the registry-backed pod
- update the ticket docs and closeout bundle

## Step 5: re-run the authenticated browser check and clean up the temporary Keycloak user

The final validation step was not just healthz and rollout status. I wanted to prove that the operator-facing browser flow still worked after the image-source change.

To do that without relying on any existing personal account, I used the shared Keycloak admin credentials already present in the Terraform `.envrc` to create a one-off test user in the `coinvault` realm, log in through the real browser flow, verify the UI, and then delete the user.

The validation user was:

- username:
  - `mysql-ide-verify-1774649669`

I do not need to preserve that user because it was created only for this check and deleted immediately afterward.

The Playwright validation succeeded:

- navigating to `https://coinvault-sql.yolo.scapegoat.dev/` redirected to Keycloak
- logging in returned to the mysql-ide UI
- the schema tree loaded
- the footer showed:
  - `Authenticated`
  - the temporary user email
  - `schema=gec`

After the check, I deleted the temporary user through the Keycloak admin API.

### What I did

- Requested a Keycloak admin token from the `master` realm.
- Created a temporary user in the `coinvault` realm.
- Reset the user password.
- Logged into the live mysql-ide UI through Playwright.
- Verified the authenticated UI state.
- Deleted the temporary user.

### What worked

- The full OIDC browser flow still worked after the registry cutover.
- The UI still loaded schema information from the live database.
- The validation left no long-term identity drift because the temporary user was removed.

### What should happen next

- finish the ticket closeout docs
- run `docmgr doctor`
- refresh the reMarkable bundle

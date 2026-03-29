---
Title: "Build Deployment Infrastructure Around a Source App Repository"
Slug: "source-app-deployment-infrastructure-playbook"
Short: "Turn a source repository into a clean GitHub Actions -> GHCR -> GitOps PR -> Argo CD deployment path."
Topics:
- ci-cd
- github
- ghcr
- argocd
- gitops
- kubernetes
- packaging
- deployment
Commands:
- git
- gh
- docker
- kubectl
- python3
Flags: []
IsTopLevel: true
IsTemplate: false
ShowPerDefault: true
SectionType: Tutorial
---

## What This Page Covers

This page is the full operator playbook for building deployment infrastructure around a normal source repository.

The concrete example is `mysql-ide`, but the point of the page is broader. A new intern should be able to read this once and understand:

- what belongs in the app repository
- what belongs in the GitOps repository
- what GitHub Actions should do
- what Argo CD should do
- how secrets and credentials should be separated
- how to support one deployment target now and multiple deployment targets later

This page exists because just knowing how to build a Docker image is not enough. A production-ish deployment path is a small system, not a single file.

## The System You Are Building

You are not “deploying from GitHub.” You are building a chain of responsibility:

```text
source repo
  -> test and build in CI
  -> publish immutable image to registry
  -> open GitOps PR against infra repo
  -> reviewer merges desired-state change
  -> Argo CD reconciles cluster
  -> Kubernetes rolls the workload
```

Each arrow is a contract boundary.

If you skip those boundaries mentally, the system becomes confusing. If you preserve them, debugging stays tractable.

## The Three Control Planes

There are three separate control planes in this model.

### 1. Source application repository

This repo owns:

- source code
- tests
- dependency lock state
- Docker build inputs
- image publishing workflow
- deployment target metadata
- the helper that opens GitOps pull requests

For `mysql-ide`, this is:

- [README.md](/home/manuel/code/wesen/2026-03-27--mysql-ide/README.md)
- [Dockerfile](/home/manuel/code/wesen/2026-03-27--mysql-ide/Dockerfile)
- [publish-image.yaml](/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml)
- [gitops-targets.json](/home/manuel/code/wesen/2026-03-27--mysql-ide/deploy/gitops-targets.json)
- [open_gitops_pr.py](/home/manuel/code/wesen/2026-03-27--mysql-ide/scripts/open_gitops_pr.py)

### 2. GitOps repository

This repo owns:

- Kubernetes manifests
- namespace and routing topology
- secrets wiring shape
- the exact pinned image tag that should run
- Argo CD `Application` definitions

For `mysql-ide`, this is:

- [mysql-ide-deployment.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml)
- [mysql-ide-service.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-service.yaml)
- [mysql-ide-ingress.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-ingress.yaml)
- [coinvault.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/coinvault.yaml)

One important migration detail is easy to miss when an app started life as a single-node manual import:

- `imagePullPolicy: Never` belongs to the old node-local image cache path
- a GHCR-backed deployment should normally use `imagePullPolicy: IfNotPresent`
- the manifest must already be on registry semantics before CI-created image PRs are safe to merge

CoinVault hit this exact transition bug. The first PR correctly changed the image tag, but the manifest was still in the old local-import mode. The right fix was not “stop using CI PRs”; it was “finish normalizing the manifest so the deployment contract matches the new release path.”

There is a second migration boundary when the source repo is private:

- GitHub Actions can still publish the image to GHCR
- but the package may remain private
- Kubernetes then fails with `401 Unauthorized` or `ImagePullBackOff` unless the cluster has credentials

That means a private-source app needs an explicit decision:

- make the package public
- add an image pull secret
- or use a documented one-node image import bridge while migrating

CoinVault exercised this exact path. The GitOps PR flow itself worked, but the node could not pull the image anonymously. The short-term recovery was to import the exact GHCR-tagged image into the node’s containerd store so the `IfNotPresent` rollout could succeed while the package visibility issue remained open.

### 3. Cluster runtime

The cluster owns:

- actual Pods
- Service networking
- TLS
- rollout behavior
- Argo reconciliation status

For this example, the live endpoint is:

- `https://coinvault-sql.yolo.scapegoat.dev`

## Why We Split the System This Way

The split is not ceremony. It solves real problems.

### Why the app repo should not deploy directly

Because Argo CD watches the GitOps repo, not the app repo.

If the app repo changes but the GitOps repo does not, Argo has no new desired state to apply.

### Why the GitOps repo should not build images

Because GitOps is about declared runtime state, not compilers, test runners, or release artifact construction.

If you put build logic into the infra repo, you confuse:

- release engineering
- deployment intent
- cluster reconciliation

### Why the cluster should not build images

Because the cluster is where you want stable, auditable runtime behavior. It is the worst place to discover that a build silently changed or that a dependency fetch now fails.

## The Deployment Architecture in Diagram Form

```text
             +-----------------------------+
             | Source repo                 |
             | mysql-ide                   |
             |                             |
             | - Go code                   |
             | - Dockerfile                |
             | - GH Actions                |
             | - target metadata           |
             +-------------+---------------+
                           |
                           | push to main
                           v
             +-----------------------------+
             | GitHub Actions              |
             |                             |
             | - go test ./...             |
             | - docker buildx             |
             | - ghcr push                 |
             | - open GitOps PR            |
             +-------------+---------------+
                           |
                           | immutable image ref
                           v
             +-----------------------------+
             | GitOps repo                 |
             | 2026-03-27--hetzner-k3s     |
             |                             |
             | - Deployment image pin      |
             | - Service                   |
             | - Ingress                   |
             | - Argo Application          |
             +-------------+---------------+
                           |
                           | merge PR
                           v
             +-----------------------------+
             | Argo CD + Kubernetes        |
             |                             |
             | - sync desired state        |
             | - roll workload             |
             | - expose HTTPS endpoint     |
             +-----------------------------+
```

## What “Packaging” Means Here

In this context, “packaging” does not just mean “Docker image.”

It means all the repo-local infrastructure required so that another operator can take the source repo and understand how it turns into a running workload.

That package includes:

- code
- tests
- build image definition
- CI workflow
- deployment target declarations
- GitOps PR updater logic
- operational README notes

For `mysql-ide`, packaging now means the repository can do all of these:

- publish `ghcr.io/wesen/2026-03-27--mysql-ide`
- define where it should be proposed for deployment
- open a PR that changes only the intended manifest line

## Standard App Repository Shape

An app repo that follows this pattern should look roughly like this:

```text
app-repo/
  cmd/ or src/
  internal/
  Dockerfile
  README.md
  .github/
    workflows/
      publish-image.yaml
  deploy/
    gitops-targets.json
  scripts/
    open_gitops_pr.py
```

### Why each file exists

`Dockerfile`

- defines the runtime artifact
- must work on a clean GitHub runner

`.github/workflows/publish-image.yaml`

- runs tests
- builds the image
- pushes to GHCR
- optionally opens GitOps PRs after publish

`deploy/gitops-targets.json`

- tells CI where that image should be proposed
- keeps deployment destinations as explicit data

`scripts/open_gitops_pr.py`

- makes the target update deterministic
- avoids hand-editing YAML in CI shell fragments
- enables local dry-run validation

## Step 1: Make Sure the App Repo Is Buildable Without Your Laptop

Before any deployment work, answer these questions:

- Can CI clone the repo?
- Can CI run tests?
- Can CI build the image without local secrets?
- Can another operator understand the build from repo contents alone?

If the answer is “no” to any of those, do not proceed to deployment automation yet.

For `mysql-ide`, the validation command is:

```bash
cd /home/manuel/code/wesen/2026-03-27--mysql-ide
go test ./...
docker build -t mysql-ide:test .
```

## Step 2: Publish an Immutable Image

The workflow should publish tags like:

- `sha-<commit>`
- `main`
- `latest`

The cluster should deploy the SHA tag.

Why:

- `latest` is convenient but poor for rollback and review
- SHA tags map directly to source commits
- a GitOps PR that updates one SHA is easy to reason about

The live workflow is:

- [publish-image.yaml](/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml)

Its logic is roughly:

```text
on pull_request:
  run tests
  build image
  do not push

on push to main:
  run tests
  build image
  push sha/main/latest tags to GHCR
  open GitOps PR with sha tag
```

## Step 3: Define Deployment Targets as Data

Do not hide target knowledge inside a workflow file.

Put it in a data file:

- [gitops-targets.json](/home/manuel/code/wesen/2026-03-27--mysql-ide/deploy/gitops-targets.json)

Current example:

```json
{
  "targets": [
    {
      "name": "coinvault-prod",
      "gitops_repo": "wesen/2026-03-27--hetzner-k3s",
      "gitops_branch": "main",
      "manifest_path": "gitops/kustomize/coinvault/mysql-ide-deployment.yaml",
      "container_name": "mysql-ide"
    }
  ]
}
```

This is important for two reasons.

First, it keeps the workflow generic. The workflow only needs to know “load targets and process them.”

Second, it makes multi-destination deployment straightforward later:

```json
{
  "targets": [
    { "name": "coinvault-prod", "...": "..." },
    { "name": "coinvault-staging", "...": "..." }
  ]
}
```

That is much cleaner than branching the workflow itself by environment names.

## Step 4: Use a Deterministic GitOps PR Updater

Do not write a one-off shell `sed` pipeline inside GitHub Actions if the change matters.

Use a small script with explicit inputs and validations:

- [open_gitops_pr.py](/home/manuel/code/wesen/2026-03-27--mysql-ide/scripts/open_gitops_pr.py)

Its responsibilities are:

- parse the target file
- select one or more targets
- patch only the matching container image field
- create a branch
- commit the manifest change
- push the branch
- open the PR

The key design property is determinism:

- one source image in
- one manifest line out
- no unrelated YAML rewrites

Pseudocode:

```text
load targets
select target(s)
for each target:
  clone gitops repo or use local checkout
  patch only matching deployment container image
  if no change:
    skip
  create branch name from app + target + image sha
  commit
  push
  open PR
```

## Step 5: Keep the GitOps Repo Focused on Runtime State

The GitOps repo should not absorb app build logic.

For `mysql-ide`, the runtime ownership stays here:

- [mysql-ide-deployment.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml)
- [mysql-ide-service.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-service.yaml)
- [mysql-ide-ingress.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-ingress.yaml)

The app repo never edits those files directly in the same commit as source changes. It proposes a PR against them.

That distinction is what makes review sane.

## Step 6: Understand the Secret Boundary

There are two separate credential stories here.

### Registry publishing

For public GHCR packages, GitHub Actions can push using the built-in `GITHUB_TOKEN`.

That is why [publish-image.yaml](/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml) uses:

- `contents: read`
- `packages: write`

### GitOps PR creation

The built-in token in the app repo should not be assumed to have cross-repo write access.

So the workflow uses a separate secret:

- `GITOPS_PR_TOKEN`

That token needs:

- `Contents: Read and write` on `wesen/2026-03-27--hetzner-k3s`
- `Pull requests: Read and write` on `wesen/2026-03-27--hetzner-k3s`

This is a good security boundary because it scopes the special write access to the one thing CI must do: propose deployment updates.

## Step 7: Avoid the GitHub Actions Secret-Gating Trap

One real bug showed up while implementing this pattern.

It is tempting to write:

```yaml
if: secrets.GITOPS_PR_TOKEN != ''
```

or:

```yaml
if: ${{ secrets.GITOPS_PR_TOKEN != '' }}
```

That looks reasonable, but GitHub workflow parsing can reject `secrets.*` in `if:` expressions during push or manual-dispatch evaluation.

The safer pattern is:

```yaml
env:
  GH_TOKEN: ${{ secrets.GITOPS_PR_TOKEN }}
run: |
  if [ -z "${GH_TOKEN}" ]; then
    echo "GITOPS_PR_TOKEN is not configured; skipping GitOps PR creation."
    exit 0
  fi
  python3 scripts/open_gitops_pr.py ...
```

That is the pattern now used in:

- [publish-image.yaml](/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml)

## Step 8: Prove the Flow Locally Before Trusting CI

Before you let CI mutate another repo, prove the updater locally.

For `mysql-ide`, the local dry-run validation is:

```bash
tmpdir=$(mktemp -d)
git clone --depth 1 /home/manuel/code/wesen/2026-03-27--hetzner-k3s "$tmpdir"

cd /home/manuel/code/wesen/2026-03-27--mysql-ide
python3 scripts/open_gitops_pr.py \
  --config deploy/gitops-targets.json \
  --target coinvault-prod \
  --image ghcr.io/wesen/2026-03-27--mysql-ide:sha-localtest \
  --gitops-repo-dir "$tmpdir" \
  --dry-run
```

What you want to see:

- one file diff
- one image line changed
- no unrelated YAML churn

## Step 9: Validate the Live End-to-End Flow

The real proof is:

1. push a commit to `main`
2. GitHub Actions publishes the image
3. GitHub Actions opens a PR into the GitOps repo
4. the PR changes one image line
5. merge the PR
6. Argo rolls the app
7. the public endpoint still works

This already happened for `mysql-ide`.

Live evidence:

- app workflow run: `23709186122`
- published image: `ghcr.io/wesen/2026-03-27--mysql-ide:sha-4757a354464846d36cb52c1b5af0bd89a4fcffea`
- GitOps PR: `wesen/2026-03-27--hetzner-k3s#1`
- merged GitOps commit: `3c779c3e72150cf380bed88760c636d1d9f15b65`
- public endpoint: `https://coinvault-sql.yolo.scapegoat.dev/healthz`

This is what a healthy PR diff should look like conceptually:

```diff
- image: ghcr.io/wesen/2026-03-27--mysql-ide:sha-old
+ image: ghcr.io/wesen/2026-03-27--mysql-ide:sha-new
```

If the PR changes more than that for a simple app rollout, stop and inspect why.

## Step 10: Plan for Multiple Deployment Destinations

Do not redesign the app repo when a second environment appears.

Instead, keep this rule:

```text
one source repo
one image pipeline
many GitOps destinations
```

That means:

- the app repo publishes one artifact family
- deployment targets are rows in `deploy/gitops-targets.json`
- different GitOps repos or branches represent different destinations

Example future shape:

```json
{
  "targets": [
    {
      "name": "coinvault-prod",
      "gitops_repo": "wesen/2026-03-27--hetzner-k3s",
      "gitops_branch": "main",
      "manifest_path": "gitops/kustomize/coinvault/mysql-ide-deployment.yaml",
      "container_name": "mysql-ide"
    },
    {
      "name": "coinvault-staging",
      "gitops_repo": "wesen/2026-04-10--staging-k3s",
      "gitops_branch": "main",
      "manifest_path": "gitops/kustomize/coinvault/mysql-ide-deployment.yaml",
      "container_name": "mysql-ide"
    }
  ]
}
```

This is one of the main reasons target metadata belongs in a data file instead of hardcoded workflow logic.

## How to Review a New App Against This Standard

When a new app repo wants to join this platform, review it in this order:

1. Can it build and test cleanly in CI?
2. Does it publish immutable GHCR images?
3. Does it declare its deployment targets explicitly?
4. Does it have a deterministic updater script?
5. Does the GitOps repo already have the right runtime package shape?
6. Does the CI-created PR only change the intended image line?
7. Does the live endpoint still validate after merge?

If any one of those is missing, the app is not fully integrated yet.

## Common Failure Modes

| Problem | Cause | Solution |
| --- | --- | --- |
| Workflow publishes image but opens no PR | `GITOPS_PR_TOKEN` missing or updater step skipped | Add the secret and verify the shell guard behavior |
| Workflow fails before starting jobs | GitHub rejects workflow syntax | Avoid `secrets.*` in `if:` expressions |
| PR changes many lines | updater script is rewriting YAML too broadly | narrow the patch logic to the exact container image field |
| Cluster does not pick up merged image | GitOps PR merged, but Argo app is not syncing | inspect the Argo `Application` status and refresh if needed |
| Image pulls fail in cluster | GHCR package is private or tag does not exist | confirm package visibility and exact image tag |
| Local dry-run works but CI PR fails | missing cross-repo token permissions | re-check `Contents` and `Pull requests` scopes on the fine-grained token |

## Recommended Rollout Order for Future Apps

Use this order:

1. make the app CI-buildable
2. publish immutable GHCR images
3. add GitOps package in this repo
4. add deployment target metadata
5. add deterministic updater
6. run local dry-run validation
7. enable CI-created GitOps PRs
8. merge the first PR manually and watch the rollout

Do not jump directly from “has Dockerfile” to “fully automated deployment.”

## The Main Lesson from `mysql-ide`

The important lesson is not “we got one app deployed.”

The important lesson is that the release path is now understandable:

- app repo builds the artifact
- CI publishes the artifact
- CI proposes deployment intent
- infra repo reviews deployment intent
- Argo applies deployment intent

That is the standard you want to repeat.

## See Also

- [public-repo-ghcr-argocd-deployment-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/public-repo-ghcr-argocd-deployment-playbook.md)
- [app-packaging-and-gitops-pr-standard.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/app-packaging-and-gitops-pr-standard.md)
- [coinvault-k3s-deployment-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/coinvault-k3s-deployment-playbook.md)

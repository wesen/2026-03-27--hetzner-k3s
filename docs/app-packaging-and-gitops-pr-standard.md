---
Title: "Standard App Packaging and CI-Created GitOps Pull Requests"
Slug: "app-packaging-and-gitops-pr-standard"
Short: "Package application repos cleanly, publish immutable images, and let CI open GitOps pull requests to update Argo CD deployments."
Topics:
- ci-cd
- github
- ghcr
- argocd
- gitops
- kubernetes
- packaging
Commands:
- git
- gh
- kubectl
- docker
- python3
Flags: []
IsTopLevel: true
IsTemplate: false
ShowPerDefault: true
SectionType: Tutorial
---

## What This Page Covers

This page defines the standard release and packaging model for application repositories that deploy into this K3s cluster.

The intended reader is a new intern who needs to understand:

- which repository owns what
- how an app should be packaged
- how images should move from source code to a running Kubernetes workload
- how to support one deployment target now and multiple deployment targets later

This matters because the cluster already has the right architecture in principle, but not yet in a fully standardized operator workflow. We already know how to publish images to GHCR and how to deploy them through Argo CD. The missing part is a repeatable handoff from app repo CI into the GitOps repo.

## The Core Model

The model has three separate control surfaces:

1. The app repository
2. The GitOps repository
3. The cluster

The app repository owns:

- source code
- tests
- Docker packaging
- image publishing
- deployment target metadata
- the workflow that opens GitOps pull requests

The GitOps repository owns:

- Kubernetes manifests
- runtime topology
- namespaces
- services
- ingress
- Vault/VSO integration
- the exact pinned image tag that should run

When an app has already been deployed through a one-off local-image import flow, the GitOps manifest must be normalized before CI-created image PRs are safe:

- switch the image reference to a registry image
- switch `imagePullPolicy` away from `Never`
- prefer `IfNotPresent` for immutable GHCR SHA tags

If this cleanup is skipped, the first CI-created PR can merge cleanly in Git while still leaving the cluster unable to pull the published image.

There is a second boundary for private repositories:

- a private source repo usually produces a private GHCR package by default
- a cluster cannot anonymously pull that image
- the deployment path must therefore include one of:
  - making the GHCR package public
  - wiring an image pull secret
  - or, as a temporary single-node bridge only, importing the exact tagged image into containerd on the node

The bridge is acceptable as a recovery technique on this single-node cluster. It is not the long-term standard.

The cluster owns:

- the live workload
- Argo CD reconciliation
- runtime secrets and networking behavior

The flow should look like this:

```text
app repo
  -> tests
  -> build image
  -> publish ghcr.io/<org>/<repo>:sha-<commit>
  -> open PR against GitOps repo
    -> reviewer merges
      -> Argo CD syncs
        -> new pod rollout in cluster
```

One additional rule is easy to miss during the first rollout of a new app:

- a new file under `gitops/applications/<name>.yaml` is only a Git declaration
- it is not automatically a live Kubernetes object unless something applies it

This repo does not currently have an app-of-apps or `ApplicationSet` layer that auto-materializes every new Argo `Application`. So the first deployment of a new app always includes a one-time bootstrap step:

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export KUBECONFIG=$PWD/kubeconfig-<server-ip>.yaml

kubectl apply -f gitops/applications/<name>.yaml
kubectl -n argocd annotate application <name> argocd.argoproj.io/refresh=hard --overwrite
```

After that initial apply, later GitOps PR merges are enough because Argo already has the `Application` object and can keep reconciling its source path.

## Why We Use CI-Created GitOps Pull Requests

This section explains the central design choice.

Why not just let the app repo deploy directly?

- Because this K3s repo is the deployment source of truth.
- Because Argo CD watches this repo, not the app repo.
- Because the desired runtime state must stay reviewable in Git.

Why not just keep manual image bumps forever?

- Because it is easy to forget.
- Because it creates unnecessary operator toil.
- Because the handoff from “published image” to “desired deployment state” should be explicit and reproducible.

Why not use Argo CD Image Updater first?

- Because it adds another controller and another mental model.
- Because the team should first master the explicit GitOps PR workflow.
- Because rollback is clearer when the image bump is a normal reviewed commit in the GitOps repo.

## Standard Packaging for Application Repositories

An app repository should have a predictable shape.

The minimum standard looks like this:

```text
app-repo/
  cmd/ or app source
  internal/ or source packages
  Dockerfile
  README.md
  .github/workflows/publish-image.yaml
  .github/workflows/open-gitops-pr.yaml   # or a second job in publish-image
  deploy/
    gitops-targets.json
  scripts/
    open_gitops_pr.py
```

Each part has a specific role.

### `Dockerfile`

This defines the build artifact. It should be usable on a clean GitHub runner without workstation-specific dependencies.

### `.github/workflows/publish-image.yaml`

This builds, tests, and publishes the image.

If GitHub CI cannot publish the GHCR image, stop and ask for guidance instead of improvising a local publishing workaround. That kind of failure usually means the release contract is wrong in one of the expected places:

- workflow permissions
- package visibility
- token scopes
- package naming or repository linkage

Manual registry pushes and node-local image imports are sometimes useful emergency bridges, but they should be explicit exceptions, not the default operator response to a broken CI publish.

It should emit immutable tags such as:

- `sha-<git-sha>`
- plus convenience tags like `main` and `latest`

Do not gate the job or step with `if: secrets.MY_SECRET != ''`. The safer pattern is:

- expose the secret through `env:`
- check for an empty value inside the shell script
- fail with `exit 1` when GitOps PR creation is part of the required release path
- only use `exit 0` when the GitOps PR step is intentionally optional for that repository

This matters because GitHub Actions workflow parsing for pushes and manual dispatch can reject `secrets.*` in `if` expressions even though the intent seems straightforward.

Initial repo bootstrap should also include setting the secret explicitly:

```bash
gh secret set GITOPS_PR_TOKEN --repo <source-repo>
```

Current `wesen-os` example:

```bash
gh secret set GITOPS_PR_TOKEN --repo wesen/wesen-os
```

### `deploy/gitops-targets.json`

This file tells CI where that image should be proposed for deployment.

It does not deploy the app directly. It defines target metadata.

Example:

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

### `scripts/open_gitops_pr.py`

This script should:

- load the target list
- update the image field in the target manifest
- create a branch
- commit the change
- push it
- open a PR

It should also support local dry-run validation so operators can test it safely before relying on CI.

The existence of this script does not remove the one-time Argo bootstrap step for a brand-new app. CI can update manifests that an existing `Application` watches, but CI cannot rely on Argo to sync an `Application` object that does not yet exist in the cluster.

## Standard Packaging for GitOps Repo App Layout

This repo does not use one single package shape for every service. That would be fake simplicity. Instead, it should standardize by category.

### Category 1: Public stateless app

Examples:

- `pretext`

Expected files:

- `namespace.yaml`
- `deployment.yaml`
- `service.yaml`
- `ingress.yaml`
- `kustomization.yaml`
- `gitops/applications/<name>.yaml`

### Category 2: Public app with Vault/VSO secrets

Examples:

- `coinvault`

Expected files:

- `namespace.yaml`
- `serviceaccount.yaml`
- `vault-connection.yaml`
- `vault-auth.yaml`
- one or more `vault-static-secret-*.yaml`
- `deployment.yaml`
- `service.yaml`
- `ingress.yaml`
- `kustomization.yaml`
- `gitops/applications/<name>.yaml`

### Category 3: Platform app with bootstrap jobs

Examples:

- `keycloak`

Expected files:

- the secret plumbing from Category 2
- bootstrap-job service accounts and auth files
- bootstrap script configmaps
- bootstrap jobs
- service, deployment, ingress
- `kustomization.yaml`
- `gitops/applications/<name>.yaml`

### Category 4: Shared data service

Examples:

- `postgres`
- `mysql`
- `redis`

Expected files:

- `namespace.yaml`
- `serviceaccount.yaml`
- `vault-connection.yaml`
- `vault-auth.yaml`
- `vault-static-secret.yaml`
- `service.yaml`
- `headless-service.yaml` if needed
- `statefulset.yaml`
- `kustomization.yaml`
- `gitops/applications/<name>.yaml`

### Category 5: Infrastructure self-hosting package

Examples:

- `argocd-public`

Expected rule:

- own only the resources whose lifecycle truly belongs to this package

That rule exists because we already saw the failure mode of hiding Argo CD public exposure inside an unrelated demo package.

## How Multiple Deployment Targets Should Work

This is the part that matters for future growth.

The app repository should publish one image artifact and support many GitOps targets.

That means:

- one app repo
- one GHCR image stream
- potentially many deployment destinations

The `deploy/gitops-targets.json` file should be an array, not a single hardcoded target.

For example:

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
      "gitops_repo": "wesen/2026-04-10--staging-cluster",
      "gitops_branch": "main",
      "manifest_path": "gitops/kustomize/coinvault/mysql-ide-deployment.yaml",
      "container_name": "mysql-ide"
    }
  ]
}
```

The important architectural idea is:

```text
build once
deploy to many targets
```

Do not create separate build systems for each destination. The image is shared. Only the target metadata differs.

## What the CI Workflow Should Do

On a successful `main` build:

1. compute the immutable tag
2. load deployment targets
3. for each target:
   - clone the GitOps repo
   - patch the manifest image field
   - create a branch
   - commit
   - push
   - open a pull request

Pseudocode:

```text
image = "ghcr.io/<org>/<repo>:sha-<github.sha>"
targets = load deploy/gitops-targets.json

for target in targets:
  repo = clone(target.gitops_repo, target.gitops_branch)
  patch_manifest_image(
    repo / target.manifest_path,
    container_name=target.container_name,
    image=image,
  )
  if no diff:
    continue
  branch = make_branch_name(target.name, image)
  commit(repo, branch)
  push(repo, branch)
  open_pull_request(repo, branch)
```

## Review and Rollback Rules

This flow is only safe if the review and rollback rules stay simple.

Reviewers should verify:

- correct target repo
- correct manifest path
- correct container name
- only the image line changed
- the PR body links back to the source workflow run and app commit

Rollback should be:

- revert the merged GitOps PR, or
- open a new PR pointing back to the previous SHA tag

That is why immutable tags in Git matter.

## Credential Boundary

The app repo workflow needs one additional credential beyond normal GHCR publishing.

It needs a token or GitHub App credential that can:

- push a branch to the GitOps repo
- open a pull request against the GitOps repo

Recommended first version:

- repository secret such as `GITOPS_PR_TOKEN`

The workflow should fail clearly or skip clearly if that secret is absent. Do not silently pretend the handoff happened when it did not.

## The First Implementation Target: `mysql-ide`

`mysql-ide` is the right first implementation target because:

- it already publishes to GHCR
- it already has a real deployment target
- it is small enough to reason about
- it already sits inside a meaningful parent application package (`coinvault`)

Its first target should be:

- repo: `wesen/2026-03-27--hetzner-k3s`
- branch: `main`
- manifest: [`gitops/kustomize/coinvault/mysql-ide-deployment.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml)
- container: `mysql-ide`

## Validation Checklist

Before you trust a new app packaging setup, check all of these:

- app repo tests pass
- image publishes to GHCR
- target metadata is valid JSON/YAML and points at a real file
- the updater changes only the expected image field
- local dry-run against a temporary GitOps clone works
- the CI workflow can open a PR
- merging the PR causes Argo CD to roll out the new image

## Related Files

- [`docs/public-repo-ghcr-argocd-deployment-playbook.md`](./public-repo-ghcr-argocd-deployment-playbook.md)
- [`gitops/applications/coinvault.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/coinvault.yaml)
- [`gitops/applications/pretext.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/pretext.yaml)
- [`gitops/applications/argocd-public.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/argocd-public.yaml)
- [`publish-image.yaml`](/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml)

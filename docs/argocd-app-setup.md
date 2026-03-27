---
Title: "Set Up an Argo CD Application in This Repository"
Slug: "argocd-app-setup"
Short: "Create or migrate an Argo CD Application for this repository, understand how Argo owns resources, and validate a clean GitOps sync state."
Topics:
- argocd
- gitops
- kustomize
- kubernetes
- deployment
Commands:
- kubectl
- git
- argocd
Flags: []
IsTopLevel: true
IsTemplate: false
ShowPerDefault: true
SectionType: Tutorial
---

## What This Page Covers

This page explains how to create, migrate, and validate an Argo CD `Application` in the context of this repository. It covers the concepts a new intern needs to understand, the current repo layout, the exact manifest shape we use, and the checks that tell you whether Argo has really adopted the resources you intended it to manage.

This matters because Argo CD is not “just another deployment command.” It is the long-term controller that continuously compares Git to the cluster. If you misunderstand how the `Application` resource works, you can create confusing drift, accidental pruning, or overlapping ownership between bootstrap, manual `kubectl`, and GitOps.

## What You Will Build

You will build an Argo CD `Application` that watches a path in this repository and deploys the Kubernetes manifests in that path into the cluster. In the current cleaned-up state, the live application is:

- name: `demo-stack`
- namespace: `argocd`
- source path: `gitops/kustomize/demo-stack`
- destination namespace: `demo`

By the end of this page you should know how to:

- create a repo-managed `Application` manifest
- decide whether the source should be Helm or Kustomize
- move an existing app from one source path to another
- validate adoption and sync state
- avoid the common traps that create `OutOfSync` noise

## Core Concepts

This section explains the ideas behind Argo CD. Read it first. A lot of operator mistakes come from trying to apply commands before understanding what object is the source of truth and what object is only an implementation detail.

### The `Application` Resource

An Argo CD `Application` is a Kubernetes custom resource that tells Argo CD where to fetch manifests from, where to deploy them, and how aggressively to keep Git and the cluster in sync.

This matters because you do not “configure Argo” in a dashboard first and then export it later. The durable unit is the `Application` YAML itself. In this repo, that durable definition lives at [`gitops/applications/demo-stack.yaml`](../gitops/applications/demo-stack.yaml).

### Source, Destination, and Sync Policy

Every `Application` has three important pieces:

- source: the Git repo, revision, and path Argo should render
- destination: the target cluster and namespace
- sync policy: whether Argo should auto-sync, prune, and self-heal

This matters because most Argo CD debugging starts by asking which of these three dimensions is wrong. A bad source path gives you render problems. A bad destination deploys to the wrong namespace. A bad sync policy changes whether Argo quietly fixes drift or waits for a human.

### Kustomize vs Helm in This Repo

The live deployment now uses Kustomize. The legacy Helm chart still exists only because bootstrap compatibility was preserved to avoid reintroducing Terraform drift on the current Hetzner server.

This matters because a new intern may see both paths and think both are equally current. They are not. The correct mental model is:

- live `Application` source: `gitops/kustomize/demo-stack`
- legacy bootstrap compatibility path: `gitops/charts/demo-stack`

### Resource Adoption

When you migrate an `Application` from one source format to another, Argo CD can often adopt the existing objects in place if the rendered resource names, namespaces, and identities remain the same.

This matters because safe migration is usually about preserving object identity. If the Kustomize package renders the same `Deployment`, `Service`, `Ingress`, and `StatefulSet` names that already exist, Argo can converge cleanly instead of deleting and recreating the whole stack.

### Sync Waves

This repo uses Argo sync-wave annotations to control apply order. Namespace and issuer resources go first, then PostgreSQL resources, then the app deployment, then the ingresses.

This matters because many failures that look like “Argo is broken” are really ordering problems. For example, an ingress that depends on a `ClusterIssuer` should not be applied before the issuer exists.

## Current Repo Layout

This section explains where to look when you are creating or changing an app definition in this repository.

- [`gitops/applications/demo-stack.yaml`](../gitops/applications/demo-stack.yaml): repo-managed `Application`
- [`gitops/kustomize/demo-stack/kustomization.yaml`](../gitops/kustomize/demo-stack/kustomization.yaml): live Kustomize entry point
- [`gitops/kustomize/demo-stack/`](../gitops/kustomize/demo-stack): live manifests Argo deploys
- [`gitops/charts/demo-stack/README.md`](../gitops/charts/demo-stack/README.md): explains the legacy chart status

## Step 1: Create the Kubernetes Manifests You Want Argo to Own

This step defines the actual resources Argo should manage. In the current repo, that means plain manifests under `gitops/kustomize/demo-stack` collected by a `kustomization.yaml`.

Why this matters: the `Application` object only points at a source path. If the manifests in that path do not reflect the live desired state, Argo will faithfully deploy the wrong thing.

Start with a `kustomization.yaml` like this:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - clusterissuer.yaml
  - postgres-service.yaml
  - postgres-statefulset.yaml
  - app-service.yaml
  - app-deployment.yaml
  - ingress.yaml
  - argocd-server-config.yaml
  - argocd-server-rollout.yaml
  - argocd-server-ingress.yaml
```

Then make sure each referenced file renders the exact object names you want the cluster to keep.

## Step 2: Create the Argo CD `Application` Manifest

This step tells Argo where the source lives and how to sync it. The current repository uses a repo-managed `Application` manifest so the live application definition itself is not trapped inside Argo CD’s UI or shell history.

Why this matters: if the application definition lives only in the cluster, interns learn the wrong habit. The correct pattern is to store the `Application` in Git too.

Example:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-stack
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  destination:
    server: https://kubernetes.default.svc
    namespace: demo
  source:
    repoURL: https://github.com/wesen/2026-03-27--hetzner-k3s.git
    targetRevision: main
    path: gitops/kustomize/demo-stack
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

This is the exact pattern used by the current deployment.

## Step 3: Validate the Render Before You Point Argo at It

This step checks the package before you let Argo manage it. With Kustomize, the easiest local render path is through `kubectl`, which already has Kustomize built in.

Why this matters: catching syntax or structure problems before the source switch is much cheaper than debugging a broken Argo sync after the application has already pointed at a new path.

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
kubectl kustomize gitops/kustomize/demo-stack
```

You are looking for:

- valid YAML output
- expected object names
- expected hostnames
- expected namespaces

## Step 4: Apply the `Application` and Trigger a Refresh

This step puts the repo-managed `Application` into the cluster and forces Argo to reconcile immediately.

Why this matters: Argo CD polls Git, but for migration work you usually want an immediate refresh so you can watch the transition and catch adoption problems quickly.

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml

kubectl apply -f gitops/applications/demo-stack.yaml
kubectl -n argocd annotate application demo-stack argocd.argoproj.io/refresh=hard --overwrite
```

## Step 5: Watch Argo Converge

This step confirms that Argo has actually moved onto the expected source and adopted the resources you intended. The application should briefly progress and then settle back to a clean state.

Why this matters: a migration can look successful at first glance while one or two resources remain `OutOfSync` due to defaulted fields, wrong names, or source mismatches.

```bash
kubectl -n argocd get application demo-stack \
  -o jsonpath='{.spec.source.path}{"\n"}{.status.sync.status}{"\n"}{.status.health.status}{"\n"}'

kubectl -n argocd get application demo-stack -o json | \
  jq -r '.status.resources[] | [.kind,.namespace,.name,.status,.health.status] | @tsv'
```

The clean target state is:

```text
gitops/kustomize/demo-stack
Synced
Healthy
```

## Step 6: Preserve Safe Boundaries with Bootstrap and Terraform

This step is conceptual rather than a single command. You need to understand where not to make the next change.

Why this matters: it is tempting to “finish the cleanup” by immediately editing `cloud-init` so first boot also points directly at Kustomize. In a greenfield repo that might be fine, but on this already-running Hetzner environment it would have changed Terraform-managed `user_data` and reopened the server-replacement problem.

The current safe boundary is:

- Kustomize is the live application source
- Terraform remains reconciled
- the legacy Helm chart remains only as first-boot compatibility

That is not perfect purity, but it is the right operational tradeoff for the existing server.

## Step 7: Validate the Whole System

This final step confirms the Argo migration did not silently break the user-facing paths or the infrastructure reconciliation state.

Why this matters: an Argo application can say `Synced` while something else regressed outside the narrow object list you were watching.

```bash
terraform plan -no-color
kubectl -n argocd get applications
curl -I https://k3s.scapegoat.dev
curl -I https://argocd.yolo.scapegoat.dev
```

You want all of the following:

- `terraform plan -no-color` shows `No changes`
- `demo-stack` is `Synced Healthy`
- both HTTPS endpoints return `HTTP/2 200`

## When to Use Helm Anyway

This section explains the boundary of the recommendation. The answer is not “Helm is always wrong.” It is “Helm is unnecessary for the current live deployment shape.”

Helm is still a good fit when:

- you need many per-environment values
- you genuinely benefit from reusable template functions
- you are publishing a package for many external consumers

Kustomize is a better fit here because:

- the manifest set is now stable
- the values are mostly fixed
- `kubectl` already renders it locally
- the team benefits from seeing plain YAML for the live deployment path

## Troubleshooting

This table focuses on the migration-specific problems that usually appear when creating or changing an Argo CD application source.

| Problem | Cause | Solution |
|---|---|---|
| The application stays `OutOfSync` after switching source paths | The Kustomize package does not render exactly the same live object identity or spec Argo expects | Compare the resource list, preserve object names, and explicitly declare Kubernetes-defaulted fields if needed |
| Argo points at the new path but the cluster becomes `Progressing` for a long time | One or more resources are still being adopted or rolled out | Wait for the sync to settle, then inspect `.status.resources` before editing anything else |
| `terraform plan` starts wanting to replace the server again | You changed bootstrap or Terraform-managed `user_data` instead of only the live app source | Back the change out of Terraform/bootstrap and move it into GitOps-managed cluster state |
| A resource disappears during migration | The new package omitted a resource that Argo now thinks should be pruned | Re-add the resource to the new source or disable prune temporarily during a carefully planned migration |
| The Kustomize render is valid, but Argo rejects it | The source path or application manifest is wrong, not the YAML syntax | Check `spec.source.path`, repo URL, target revision, and namespace |

## See Also

- [Set Up a Hetzner K3s Server for This Repository](./hetzner-k3s-server-setup.md) — full infrastructure-to-validation workflow
- [`gitops/applications/demo-stack.yaml`](../gitops/applications/demo-stack.yaml) — current live `Application`
- [`gitops/kustomize/demo-stack/kustomization.yaml`](../gitops/kustomize/demo-stack/kustomization.yaml) — current live Kustomize package
- [`gitops/charts/demo-stack/README.md`](../gitops/charts/demo-stack/README.md) — explains the remaining bootstrap compatibility layer

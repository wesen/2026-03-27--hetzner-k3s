---
Title: Investigation diary for Vault-backed GHCR image pull secrets
Ticket: HK3S-0014
Status: active
Topics:
    - argocd
    - ghcr
    - gitops
    - kubernetes
    - vault
    - packaging
DocType: reference
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: Chronological research and implementation diary for the private-image pull-secret pattern.
LastUpdated: 2026-03-29T10:05:00-04:00
WhatFor: Preserve the actual reasoning trail behind the private GHCR pull-secret design.
WhenToUse: Use when reviewing why this pattern was proposed and which current files it needs to touch.
---

# Investigation diary for Vault-backed GHCR image pull secrets

## Goal

Capture the concrete local and operational evidence behind the pull-secret recommendation.

## Context

The trigger for this ticket was the first live CoinVault GHCR rollout under `HK3S-0013`.

What worked:

- source-repo image publishing
- CI-created GitOps PR creation
- Argo reconciliation to the new image tag

What failed:

- kubelet could not pull the private GHCR package anonymously

This produced a real runtime error:

```text
failed to authorize:
failed to fetch anonymous token:
401 Unauthorized
```

That made it clear that package visibility and runtime registry authentication need their own documented pattern.

## Quick Reference

### Relevant local files

- [serviceaccount.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/serviceaccount.yaml)
- [deployment.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/deployment.yaml)
- [vault-static-secret-runtime.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/vault-static-secret-runtime.yaml)
- [publish-image.yaml](/home/manuel/code/gec/2026-03-16--gec-rag/.github/workflows/publish-image.yaml)
- [app-packaging-and-gitops-pr-standard.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/app-packaging-and-gitops-pr-standard.md)

### Relevant upstream docs

- Kubernetes private registry pulls:
  - https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
  - https://kubernetes.io/docs/concepts/containers/images/
- GitHub Container Registry:
  - https://docs.github.com/packages/getting-started-with-github-container-registry/about-github-container-registry

### Current recommended end state

```text
Vault secret
  -> VSO sync
  -> dockerconfigjson secret
  -> ServiceAccount imagePullSecrets
  -> Pod pulls private GHCR image
```

### Current non-goal

Do not redesign the GitOps PR flow in this ticket. That part is already proven in `HK3S-0013`.

## Usage Examples

### When reviewing the current CoinVault state

Use this sequence:

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml

kubectl -n coinvault get deployment coinvault \
  -o jsonpath='{.spec.template.spec.containers[0].image}{" "}{.spec.template.spec.containers[0].imagePullPolicy}{"\n"}'
kubectl -n argocd get application coinvault \
  -o jsonpath='{.status.sync.status} {.status.health.status} {.status.sync.revision}{"\n"}'
```

### When explaining the failure to a new operator

Use this mental model:

```text
publish image success
  does not imply
cluster pull success

GitOps PR success
  does not imply
registry auth success
```

### 2026-03-29: Current evidence snapshot

- `coinvault` source repo is private
- the first GHCR-backed rollout failed anonymously
- the workload recovered only after importing the tagged image into the single node’s containerd cache
- therefore the missing layer is image pull auth, not image build or GitOps release automation

### 2026-03-29: First implementation decisions

Before touching Vault or GitOps state, I verified the VSO capabilities already installed in the cluster.

Commands:

```bash
KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml \
  kubectl explain vaultstaticsecret.spec.destination --api-version=secrets.hashicorp.com/v1beta1

KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml \
  kubectl explain vaultstaticsecret.spec.destination.transformation --api-version=secrets.hashicorp.com/v1beta1

KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml \
  kubectl explain vaultstaticsecret.spec.destination.transformation.templates --api-version=secrets.hashicorp.com/v1beta1
```

Observed result:

- `destination.type` is supported
- `destination.transformation` is supported
- `destination.transformation.templates` is supported
- templates are Go text templates

That is enough to choose the clean path:

- create a Vault record with raw GHCR fields
- let `VaultStaticSecret` render `.dockerconfigjson` directly
- avoid inventing a second controller or ad-hoc transform job unless the first render attempt proves insufficient

Implementation decisions made at this checkpoint:

1. Credential source
   - use the locally supplied `GITHUB_DEPLOY_PAT` once
   - import it into Vault
   - stop depending on `.envrc` after that

2. Vault path contract
   - use a dedicated CoinVault path rather than overloading the runtime secret
   - recommended path:
     - `kv/apps/coinvault/prod/image-pull`

3. Secret materialization model
   - target Kubernetes secret type:
     - `kubernetes.io/dockerconfigjson`
   - target data key:
     - `.dockerconfigjson`

4. Workload attachment model
   - attach the resulting secret through the existing `coinvault` `ServiceAccount`
   - avoid duplicating `imagePullSecrets` directly in every pod spec unless a later app has a stronger reason

This was the right moment to lock those choices down because they affect every YAML resource that comes next.

### 2026-03-29: First GitOps scaffold added

After the design choices were explicit, I added the first real implementation slice in Git:

- [`scripts/bootstrap-coinvault-image-pull-secret.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-coinvault-image-pull-secret.sh)
  - seeds `kv/apps/coinvault/prod/image-pull`
  - requires `GITHUB_DEPLOY_PAT`
  - computes the base64 `auth` field once at write time
- [`vault-static-secret-image-pull.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/vault-static-secret-image-pull.yaml)
  - renders `.dockerconfigjson` directly with `destination.type = kubernetes.io/dockerconfigjson`
- [`serviceaccount.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/serviceaccount.yaml)
  - adds `imagePullSecrets: [coinvault-ghcr-pull]`
- [`kustomization.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/kustomization.yaml)
  - includes the new `VaultStaticSecret`

The important implementation detail here is that I chose not to compute base64 inside the template. The installed VSO template path clearly supports `text/template`, but there was no reason to depend on extra helper functions when the source secret can simply carry:

- `server`
- `username`
- `password`
- `auth`

That keeps the Kubernetes-side template intentionally dumb.

Validation at this checkpoint:

```bash
chmod +x scripts/bootstrap-coinvault-image-pull-secret.sh
KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl kustomize gitops/kustomize/coinvault >/dev/null
```

Observed result:

- Kustomize rendered successfully
- no YAML schema error blocked the new resource set

This is the right place for the first commit because it isolates:

- repo-side scaffold changes
- before secret writes
- before Argo reconciliation
- before any risky rollout test

## Related

- [01-vault-backed-ghcr-image-pull-secret-pattern-for-private-app-images.md](../design-doc/01-vault-backed-ghcr-image-pull-secret-pattern-for-private-app-images.md)
- [01-implement-vault-backed-ghcr-image-pull-secrets-in-k3s.md](../playbook/01-implement-vault-backed-ghcr-image-pull-secrets-in-k3s.md)
- [HK3S-0013 index](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/28/HK3S-0013--automate-gitops-image-bumps-and-standardize-app-packaging-layout/index.md)

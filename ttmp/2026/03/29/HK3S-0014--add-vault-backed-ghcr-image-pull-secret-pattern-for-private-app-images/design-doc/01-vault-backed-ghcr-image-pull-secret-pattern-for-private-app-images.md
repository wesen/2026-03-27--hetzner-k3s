---
Title: Vault-backed GHCR image pull secret pattern for private app images
Ticket: HK3S-0014
Status: active
Topics:
    - argocd
    - ghcr
    - gitops
    - kubernetes
    - vault
    - packaging
DocType: design-doc
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: Design the long-term Kubernetes image pull secret pattern for private GHCR-backed apps, with CoinVault as the first target.
LastUpdated: 2026-03-29T10:40:00-04:00
WhatFor: Explain the architecture, tradeoffs, and implementation shape for pulling private GHCR images in-cluster through Vault-managed credentials.
WhenToUse: Use when designing private-image rollout paths for apps that already publish to GHCR but cannot be pulled anonymously by K3s.
---

# Vault-backed GHCR image pull secret pattern for private app images

## Executive Summary

This design proposes a standard private-registry pull path for this K3s cluster:

- keep publishing private app images from source repositories through GitHub Actions into GHCR
- keep using CI-created GitOps pull requests to update pinned image tags in this repository
- add a Vault-backed Kubernetes image pull secret pattern so workloads can pull private GHCR packages at runtime

The first concrete target is `coinvault`.

Today, `coinvault` only succeeds because the exact GHCR-tagged image was manually imported into the single K3s node’s containerd store after the rollout hit `401 Unauthorized`. That proved the GitOps release automation worked, but it also proved that package visibility is a separate runtime contract.

The recommended long-term pattern is:

```text
Vault
  -> image-pull credential record
  -> VSO sync
  -> kubernetes.io/dockerconfigjson secret
  -> ServiceAccount imagePullSecrets
  -> Pod pulls private GHCR image
```

That keeps secret ownership in Vault, lets Argo continue to own manifests, and removes the need for node-local import bridges.

## Problem Statement

Private-source applications now have a release path that is only half-finished.

What already works:

- the source repo can build and publish an immutable GHCR image
- the source repo can open a GitOps PR into this repository
- Argo CD can reconcile the new image tag into the cluster

What does not yet work by default:

- kubelet cannot pull a private GHCR package anonymously
- the cluster therefore enters `ErrImagePull` / `ImagePullBackOff`
- the current recovery depends on manually importing the image into the single node

The immediate evidence came from CoinVault:

```text
Failed to pull image "ghcr.io/wesen/2026-03-16--gec-rag:sha-d074c80":
failed to authorize:
failed to fetch anonymous token:
401 Unauthorized
```

This is not a GitOps problem.

It is not a GHCR publish problem either.

It is a registry-authentication problem at pod startup time.

The system therefore needs a registry credential path that is:

- GitOps-managed in shape
- Vault-backed in secret ownership
- reusable across private apps
- explicit enough that a new intern can operate it safely

## Proposed Solution

### The architecture

The recommended architecture is:

```text
GitHub
  -> private repo publishes image to GHCR

Vault
  -> stores GHCR username/token/server

VSO
  -> syncs those values into Kubernetes

Kubernetes
  -> materializes .dockerconfigjson secret
  -> attaches secret to ServiceAccount
  -> pods pull private image normally
```

### The data model

At minimum, the credential record needs:

- `server`: `ghcr.io`
- `username`: GitHub username or machine account name
- `password`: a token with package pull permissions

The resulting Kubernetes secret should be of type:

- `kubernetes.io/dockerconfigjson`

with data key:

- `.dockerconfigjson`

whose decoded JSON looks like:

```json
{
  "auths": {
    "ghcr.io": {
      "username": "wesen",
      "password": "ghp_...",
      "auth": "base64(username:password)"
    }
  }
}
```

In the implemented CoinVault path, VSO also leaves an extra `_raw` key in the generated secret. That key is harmless for kubelet because the required `.dockerconfigjson` key is present and the secret type is correct. Operators should validate the required key rather than assume the secret will contain only one key.

### The control-plane split

The app source repo still owns:

- image publishing
- GitOps PR creation

This GitOps repo still owns:

- workload manifests
- service account references
- the image tag that should run

Vault still owns:

- the actual registry credential

This split is important because it preserves the working release model that was just proven in `HK3S-0013`.

### The first target: CoinVault

The first concrete implementation should wire this into:

- [serviceaccount.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/serviceaccount.yaml)
- [deployment.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/deployment.yaml)
- [vault-static-secret-runtime.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/vault-static-secret-runtime.yaml)

The target outcome is:

```text
coinvault ServiceAccount
  imagePullSecrets:
    - coinvault-ghcr-pull

coinvault Deployment
  serviceAccountName: coinvault
  image: ghcr.io/wesen/2026-03-16--gec-rag:sha-...
  imagePullPolicy: IfNotPresent
```

The implemented Kubernetes object names are:

- `VaultStaticSecret/coinvault-ghcr-pull`
- `Secret/coinvault-ghcr-pull`
- `ServiceAccount/coinvault`

### Pseudocode for the end state

```text
on pod startup:
  kubelet reads imagePullSecrets from ServiceAccount
  kubelet loads dockerconfigjson secret
  kubelet authenticates to ghcr.io
  kubelet pulls image
  pod starts
```

### Pseudocode for the validation proof

```text
remove cached image from node
  -> restart deployment
  -> kubelet consults imagePullSecrets
  -> kubelet authenticates to ghcr.io
  -> kubelet pulls the image again
  -> pod becomes Ready
  -> Argo remains Synced Healthy
```

## Design Decisions

### Decision 1: Use Vault as the source of truth for registry credentials

Rationale:

- consistent with the rest of the platform
- avoids storing registry tokens in git
- keeps app secret ownership centralized

### Decision 2: Keep the GitOps PR model unchanged

Rationale:

- the release handoff is already working
- the missing layer is runtime pull auth, not deployment intent
- changing both systems at once would blur the debugging boundary

### Decision 3: Attach image pull credentials through `ServiceAccount`

Rationale:

- cleaner than repeating `imagePullSecrets` on every pod template
- makes the secret boundary explicit at the workload identity layer
- easier to reuse if more than one pod in the namespace needs the same private image source

### Decision 4: Treat the node-local containerd import as a temporary bridge only

Rationale:

- acceptable on a single-node cluster as a short-term recovery path
- not acceptable as the steady-state deployment model
- hides real package-auth failures instead of fixing them

### Decision 5: First solve GHCR pull auth for one app, then generalize

Rationale:

- CoinVault is the first real private-source app already on the new release path
- it gives us a real target and real validation
- once the pattern works there, it can be copied to future private apps

## Alternatives Considered

### Alternative A: Make every GHCR package public

Advantages:

- simplest runtime path
- no Kubernetes registry secret needed

Why it is not the general answer:

- not every private-source app should expose its image publicly
- package visibility is a policy decision, not just a technical convenience

### Alternative B: Keep importing images into containerd on the node

Advantages:

- works today on a single-node cluster
- no extra Kubernetes secret design needed

Why it is rejected as the standard:

- not scalable to multi-node clusters
- not self-healing
- bypasses the real registry auth contract
- easy to forget during future rollouts

### Alternative C: Use Terraform to manage the registry secret outside the cluster

Advantages:

- explicit infrastructure ownership

Why it is rejected:

- wrong control loop for per-app runtime credential delivery
- splits secret lifecycle away from Vault/VSO
- less consistent with how app secrets already work here

### Alternative D: Put the token directly into a Kubernetes secret by hand

Advantages:

- quick to implement

Why it is rejected:

- not GitOps-safe
- not Vault-backed
- drifts immediately
- teaches the wrong pattern

## Implementation Plan

1. Decide the exact GHCR credential object.
   Likely a GitHub PAT classic with `read:packages`.

2. Create the Vault path contract.
   Example:
   - `kv/apps/coinvault/prod/image-pull`

3. Decide the secret materialization mechanism.
   Either:
   - VSO directly writes `kubernetes.io/dockerconfigjson`
   - or a small transform job creates it from synced raw fields

4. Add the GitOps resources to `coinvault`.
   - image-pull secret sync resource
   - possibly a transform job or secret template
   - `ServiceAccount` update

5. Validate rollout.
   - remove reliance on the node-cache bridge
   - confirm kubelet can pull the private image directly

6. Document the pattern in `docs/`.
   Once implemented, this ticket should feed back into the operator docs so future apps do not rediscover the same issue.

### Suggested resource topology

```text
gitops/kustomize/coinvault/
  serviceaccount.yaml
  vault-auth.yaml
  vault-connection.yaml
  vault-static-secret-runtime.yaml
  vault-static-secret-image-pull.yaml   # likely new
  dockerconfigjson-transform.yaml       # maybe needed
  deployment.yaml
```

### API references

- Kubernetes image pull secrets:
  - https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
  - https://kubernetes.io/docs/concepts/containers/images/
- GHCR authentication:
  - https://docs.github.com/packages/getting-started-with-github-container-registry/about-github-container-registry

## Open Questions

1. Can the current VSO version materialize `kubernetes.io/dockerconfigjson` directly in a clean way, or do we need a small transform step?
2. Should the pull credential be app-specific, org-wide, or handled through a dedicated machine account?
3. For private-source apps, do we prefer:
   - private package + pull secret
   - or public package + no pull secret
4. Once the pull-secret path exists, should the temporary containerd import bridge be removed from the CoinVault operational docs immediately?

## References

- [HK3S-0013 index](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/28/HK3S-0013--automate-gitops-image-bumps-and-standardize-app-packaging-layout/index.md)
- [app-packaging-and-gitops-pr-standard.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/app-packaging-and-gitops-pr-standard.md)
- [source-app-deployment-infrastructure-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/source-app-deployment-infrastructure-playbook.md)
- [serviceaccount.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/serviceaccount.yaml)
- [deployment.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/deployment.yaml)

---
Title: First app migration diary
Ticket: HK3S-0007
Status: active
Topics:
    - vault
    - k3s
    - migration
    - gitops
    - applications
DocType: reference
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: Chronological diary for choosing and implementing the first real application migration onto K3s using Vault-managed secrets.
LastUpdated: 2026-03-27T16:05:00-04:00
WhatFor: Use this to review the exact decisions, commands, and reasoning behind the first real application migration after the Vault platform work.
WhenToUse: Read this when continuing or reviewing HK3S-0007.
---

# First app migration diary

## Goal

Choose the first real application to deploy on K3s using the new Vault plus VSO platform path, then document and execute that migration with enough detail that the next app migration is easier.

## Step 1: Compare candidates and choose the first app based on deployability, not just secret simplicity

I started HK3S-0007 by revisiting the candidate list from the earlier platform design. The original tension was straightforward: hair-booking had the simpler secret story, while CoinVault had the richer existing hosted runtime contract. At the platform-design stage that was still an open question. For actual implementation, I needed to answer a stricter question: which app can be recreated as a real K3s workload now, not just theoretically later.

I re-read the current HK3S-0007 ticket, the earlier migration design ticket, the hair-booking Vault SES handoff, and the current CoinVault deployment contract. That comparison changed the framing. Hair-booking does have a narrow Vault policy and a very simple secret path at `kv/apps/hair-booking/prod/ses`, but the repository itself is not yet a real hosted service contract. It has no meaningful K8s packaging, no actual runtime deployment documentation, and no obvious backend container entrypoint to move. It is a simpler secret integration, but not a simpler application migration.

CoinVault is the opposite. It has more moving parts, but it is a real deployable service today:

- a Dockerfile
- a hosted runtime contract
- a health check
- a public route surface
- an existing Keycloak OIDC integration
- an existing Vault-backed runtime contract
- a known MySQL dependency and local SQLite persistence paths

That made the decision much clearer. For the first K3s migration ticket, the right criterion is "smallest realistic end-to-end hosted workload," not "smallest isolated secret."

### What I did
- Read the HK3S-0007 index, plan, and tasks.
- Re-read the earlier platform design and migration guidance from HK3S-0002.
- Read the hair-booking SES/Vault handoff document and current least-privilege policy.
- Read the CoinVault Coolify deployment contract, hosted operations playbook, Dockerfile, runtime bootstrap code, and entrypoint.
- Confirmed the live K3s cluster already has the platform layers this app needs:
  - Vault
  - Vault Kubernetes auth
  - Vault Secrets Operator

### Why
- The first migration needs to end in a live workload. A simpler secret contract is not enough if the app itself is not ready to host.

### What worked
- The comparison produced a decisive answer instead of another round of ambiguous “maybe later” analysis.
- CoinVault’s existing docs are strong enough that I can translate them into K3s primitives rather than inventing a deployment from scratch.

### What didn't work
- I initially expected hair-booking to remain the favorite because of its smaller Vault surface. Once I looked at the repo shape, that assumption did not hold up.
- My first `docmgr doc add` attempt used `--type` instead of `--doc-type`, which failed with `unknown flag: --type`.

### What I learned
- The right first migration target is the simplest *deployable* app, not the simplest *secret path*.
- CoinVault can likely run on K3s without its old AppRole bootstrap path if VSO provides the runtime env values and the Pinocchio YAML as Kubernetes-native inputs.

### What was tricky to build
- The trickiest part was not the tech; it was being honest about the decision criteria. Hair-booking is the cleaner secret example, but not the cleaner first hosted migration.

### What warrants a second pair of eyes
- Review the decision criteria before the live deploy work goes further: if someone strongly prefers a purely lower-risk secret demo, that should be a separate ticket, not this “first real application” ticket.

### What should be done in the future
- Write the runtime contract for CoinVault on K3s, then scaffold the Argo app, VSO resources, and deployment manifests.

## Step 2: Translate the CoinVault hosted contract into K3s primitives and helper scripts

After locking the app choice, I mapped the existing CoinVault runtime contract into K3s objects instead of copying the old Coolify bootstrap literally. The key insight from the app repo was that CoinVault does not actually require AppRole when running inside Kubernetes. The old bootstrap binary existed to fetch secret material into a container running outside the cluster. On K3s, VSO can provide those values as Kubernetes-native inputs instead.

That led to the concrete K3s shape:

- an Argo CD application named `coinvault`
- a local Kustomize package under `gitops/kustomize/coinvault`
- namespace `coinvault`
- service account `coinvault`
- one PVC for the timeline and turns SQLite files
- one `VaultConnection`
- one `VaultAuth`
- two `VaultStaticSecret` resources:
  - `coinvault-runtime`
  - `coinvault-pinocchio`
- one deployment, service, and ingress

I also added three helper scripts because this ticket needs more than manifests. It needs operator procedures:

- [`seed-coinvault-k3s-vault-secrets.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/seed-coinvault-k3s-vault-secrets.sh)
  - copies the current CoinVault runtime and Pinocchio secrets from the old Vault into the K3s Vault and overrides the public URL for the K3s hostname
- [`build-and-import-coinvault-image.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/build-and-import-coinvault-image.sh)
  - builds the app image from the private CoinVault repo and imports it directly into the single K3s node’s containerd image store
- [`validate-coinvault-k3s.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-coinvault-k3s.sh)
  - checks the Argo app, deployment, VSO destination secrets, health endpoint, and login redirect

The image-import script is intentionally documented as a bootstrap exception, not the desired long-term model. The real long-term answer is a registry-backed image publish path. But for a single-node cluster and a private repo with no package scope ready, direct import is the most pragmatic way to land the first live migration without adding another platform ticket first.

### What I did
- Added [coinvault.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/coinvault.yaml).
- Added the full Kustomize package under [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault).
- Chose the runtime shape:
  - VSO-backed env secret for runtime values
  - VSO-backed mounted secret for Pinocchio YAML
  - static K3s hostname and OIDC issuer/client ID values in the deployment manifest
- Added the Vault-seed, image-import, and validation scripts.
- Updated the ticket tasks and changelog to reflect that the repo-managed scaffold now exists.

### Why
- The first migrated app should use the new K3s platform path, not drag the off-cluster AppRole pattern into the cluster unnecessarily.
- A single scaffold pass keeps the runtime contract coherent and easier to review.

### What worked
- The existing CoinVault entrypoint is already flexible enough to run without bootstrap mode as long as the needed env vars and profile files are present.
- The earlier planning work had already committed the `coinvault-prod` Vault policy and Kubernetes role, which reduced the new Vault-side work.

### What didn't work
- Nothing failed structurally in this step. The main complexity was choosing which values should stay static in the deployment and which should remain Vault-backed.

### What I learned
- CoinVault is a strong first migration target because the old hosted contract is explicit enough to translate directly into K8s resources.
- The biggest real blocker is image distribution, not secret delivery.

### What was tricky to build
- The trickiest part was deciding not to overfit the old bootstrap path. Inside K3s, VSO is the better primitive.

### What warrants a second pair of eyes
- Review the image-import exception carefully. It is pragmatic, but it should stay clearly documented as temporary.

### What should be done in the future
- Validate the scaffold locally, then perform the live rollout: seed secrets, adjust Keycloak redirect URIs, import the image, apply the Argo app, and validate the public runtime.

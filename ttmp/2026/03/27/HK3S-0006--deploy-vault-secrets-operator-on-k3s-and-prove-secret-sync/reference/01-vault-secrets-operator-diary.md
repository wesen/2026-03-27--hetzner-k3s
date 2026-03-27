---
Title: Vault Secrets Operator implementation diary
Ticket: HK3S-0006
Status: active
Topics:
    - vault
    - k3s
    - kubernetes
    - gitops
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: gitops/applications/vault-secrets-operator.yaml
      Note: Repo-managed Argo CD application for the HashiCorp VSO Helm chart
    - Path: gitops/applications/vault-secrets-operator-smoke.yaml
      Note: Repo-managed Argo CD application for the smoke VaultConnection/VaultAuth/VaultStaticSecret objects
    - Path: scripts/bootstrap-vault-kubernetes-auth.sh
      Note: Existing Vault Kubernetes-auth bootstrap helper extended for the VSO smoke role and source path
    - Path: scripts/validate-vault-secrets-operator.sh
      Note: Validation helper for destination secret sync, rotation, and failure mode checks
ExternalSources: []
Summary: Chronological diary for deploying Vault Secrets Operator on K3s and proving the first Vault-to-Kubernetes secret sync path.
LastUpdated: 2026-03-27T14:35:00-04:00
WhatFor: Use this to review the exact implementation trail for the first controller-based secret delivery slice on the K3s cluster.
WhenToUse: Read this when continuing or reviewing the VSO implementation ticket.
---

# Vault Secrets Operator implementation diary

## Goal

Capture the implementation work for installing Vault Secrets Operator, wiring it to the K3s Vault through Kubernetes auth, and proving a real secret sync into a Kubernetes `Secret`.

## Step 1: Confirm the operator packaging and choose the narrowest smoke-auth model

The first thing I did in this ticket was decide how to package VSO in a way that matches the existing repo instead of introducing a second GitOps pattern. The current repo already uses an external Helm-chart Argo application for Vault itself, and a separate local Argo application for the Kubernetes-auth smoke resources. VSO fits that exact same split well: install the controller from the official HashiCorp Helm chart in its own application, then keep the first `VaultConnection`, `VaultAuth`, and `VaultStaticSecret` objects in a separate repo-local smoke application.

I also chose the smallest useful auth model for the first proof: a dedicated smoke namespace and service account, a dedicated Vault policy/role under the existing `auth/kubernetes` mount, and a single `VaultStaticSecret` that creates one destination Kubernetes `Secret`. That proves the full path without pulling a real application into the ticket prematurely.

### Prompt Context

**User prompt (verbatim):** "yes, do next ticket, task by task, committing at appropriate intervals, keeping a detailed diary."

**Assistant interpretation:** Start implementing `HK3S-0006` for real, keep checkpoints focused, and document the work as it happens.

**Inferred user intent:** Move from auth foundations to controller-based secret delivery, not just planning.

### What I did
- Read `HK3S-0006` index, tasks, and plan.
- Checked the live cluster for existing VSO CRDs and namespaces.
- Re-read the earlier design doc sections that recommended separate Argo applications for Vault and VSO.
- Pulled the official HashiCorp VSO docs and CR examples to confirm the current API surface.
- Chose:
  - operator namespace: `vault-secrets-operator-system`
  - smoke namespace: `vault-secrets-operator-smoke`
  - smoke service account / Vault role / policy: `vso-smoke`

### Why
- A split controller-app plus smoke-app model keeps lifecycle and troubleshooting clearer.
- The first proof should be small enough that failures are attributable to the controller or auth path, not app-specific complexity.

### What worked
- The existing repo structure already suggested the right packaging pattern.
- Official docs confirmed `VaultConnection`, `VaultAuth`, and `VaultStaticSecret` as the right CRD set for the first slice.

### What didn't work
- Nothing failed conceptually here. The only friction was that the local environment does not have `helm`, so I used the official chart index and docs directly instead of local Helm inspection.

### What I learned
- The current official VSO chart version in HashiCorp's Helm repo is `1.3.0`.
- The current CRD version is `secrets.hashicorp.com/v1beta1`.

### What was tricky to build
- The main design edge was choosing the ownership boundary. The controller install belongs in an external-chart Argo app. The auth and smoke objects belong in repo-local manifests so they remain easy to review and adapt later for real apps.

### What warrants a second pair of eyes
- Whether the first `VaultConnection` should use the in-cluster Vault service or the public Vault hostname. I chose the in-cluster service to keep the first proof independent of ingress/TLS.

### What should be done in the future
- Add the full scaffold next, then apply it live and validate propagation.

### Code review instructions
- Review:
  - [01-vault-secrets-operator-plan.md](../playbooks/01-vault-secrets-operator-plan.md)
  - `ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/design-doc/01-vault-on-k3s-and-gitops-migration-design.md`
- Confirm the controller-app plus smoke-app split is the right first shape.

### Technical details
- Official references used:
  - `https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso/helm`
  - `https://raw.githubusercontent.com/hashicorp/vault-secrets-operator/main/config/samples/secrets_v1beta1_vaultauth.yaml`
  - `https://raw.githubusercontent.com/hashicorp/vault-secrets-operator/main/config/samples/secrets_v1beta1_vaultstaticsecret.yaml`

## Step 2: Add the repo-managed VSO scaffold and validation helper

After deciding the packaging model, I created the repo-managed scaffold for both halves of the deployment. The controller half is the Argo application in [`vault-secrets-operator.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-secrets-operator.yaml), which points at the official HashiCorp Helm chart and installs the controller into `vault-secrets-operator-system`. The smoke half is the local package in [`kustomization.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/kustomization.yaml), applied through the companion Argo application in [`vault-secrets-operator-smoke.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-secrets-operator-smoke.yaml).

I also extended the existing Vault Kubernetes-auth bootstrap helper in [`bootstrap-vault-kubernetes-auth.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-kubernetes-auth.sh) so it now writes the `vso-smoke` policy and role, plus the seed source data at `kv/apps/vso-smoke/dev/demo`. The smoke CRs themselves are intentionally small: a namespace, a service account, a `VaultConnection` that targets the in-cluster Vault service, a `VaultAuth` that uses the `kubernetes` auth mount and the `vso-smoke` role, and a `VaultStaticSecret` that writes to `Secret/vso-smoke-secret`.

The last part of this step was the end-to-end validation helper in [`validate-vault-secrets-operator.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-vault-secrets-operator.sh). I wanted that script to prove more than just installation. It checks that both Argo apps are healthy, the controller is rolled out, the destination secret is created, a source-path update propagates, and a temporary unauthorized `VaultStaticSecret` fails with a recognizable policy error.

### What I did
- Added the controller Argo application for the HashiCorp Helm chart.
- Added the local Kustomize smoke package and its companion Argo application.
- Added the `vso-smoke` Vault policy and role files.
- Extended the existing Vault Kubernetes-auth bootstrap script to write the new policy, role, and seed secret path.
- Added the end-to-end validation script.
- Added the first implementation diary file.

### Why
- The scaffold has to exist in Git before the live Argo apply, otherwise the cluster would reconcile a path that does not exist on `main`.
- The validation script needs to prove the security boundary, not just the happy path.

### What worked
- `kubectl kustomize gitops/kustomize/vault-secrets-operator-smoke` rendered cleanly.
- `bash -n` passed on both bootstrap and validation scripts.
- `git diff --check` was clean before the first commit.

### What didn't work
- Nothing structurally failed in this step. The main constraint was that the local environment did not have `helm`, so I stayed on the official docs and chart index rather than inspecting the chart locally.

### What I learned
- The split controller-app plus smoke-app model maps cleanly onto the repo conventions we already established for other platform components.
- A dedicated denied-path probe is important because a success-only smoke test can hide overly broad policies.

### What was tricky to build
- The biggest design choice was the boundary between "upstream chart content" and "cluster-specific auth/config objects". Using two Argo applications made that boundary clear.

### What warrants a second pair of eyes
- Whether we eventually want one shared `VaultConnection` per namespace or to keep app-local connections for explicitness.

### What should be done in the future
- Deploy the scaffold live and verify real sync behavior against the running cluster.

### Code review instructions
- Review:
  - [vault-secrets-operator.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-secrets-operator.yaml)
  - [vault-secrets-operator-smoke.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-secrets-operator-smoke.yaml)
  - [kustomization.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/kustomization.yaml)
  - [validate-vault-secrets-operator.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-vault-secrets-operator.sh)
- Confirm the install split and the Vault policy boundaries make sense before relying on the live rollout.

### Technical details
- Commit checkpoint: `cff552f` `feat: add vault secrets operator scaffold`

## Step 3: Deploy VSO live, prove secret sync, and prove the deny boundary

With the scaffold pushed to `main`, I applied the controller Argo application first so the live cluster could reconcile the official chart. I used:

```bash
kubectl apply -f gitops/applications/vault-secrets-operator.yaml
```

Then I re-ran the Vault Kubernetes-auth bootstrap so the new `vso-smoke` role and seed data definitely existed in the live Vault:

```bash
export VAULT_ADDR=https://vault.yolo.scapegoat.dev
export VAULT_TOKEN='<redacted-root-token>'
./scripts/bootstrap-vault-kubernetes-auth.sh
```

That completed successfully, though Vault warned about default token audiences on all the roles. The important part was the final success output:

```text
vault kubernetes auth bootstrap complete
policies: 4
roles: 4
```

After that, I waited for the controller to come up and confirmed the CRDs were installed. Only then did I apply the smoke application:

```bash
kubectl apply -f gitops/applications/vault-secrets-operator-smoke.yaml
```

Once both Argo apps were `Synced Healthy`, I inspected the smoke namespace and confirmed the expected resources existed and reported healthy conditions. I also inspected the live `VaultStaticSecret` status directly to verify `SecretSynced=True`, `Healthy=True`, and `Ready=True`.

The most important validation came from the script. My first attempt failed because I had forgotten to mark the script executable:

```text
zsh:1: permission denied: ./scripts/validate-vault-secrets-operator.sh
```

I fixed that with `chmod +x scripts/validate-vault-secrets-operator.sh` and reran the validation with the live kubeconfig and Vault environment. The script passed. It verified:

- the destination secret was created
- the source password changed from `vso-secret` to `vso-secret-rotated`
- the destination secret updated accordingly
- a temporary denied CR failed with a recognizable permission error

That denial check matters. It proves the role/policy boundary is actually doing work instead of granting broad access accidentally.

### What I did
- Applied the controller Argo application.
- Re-ran the Vault Kubernetes-auth bootstrap with the new smoke role and source path.
- Waited for the controller deployment and CRDs to become ready.
- Applied the smoke Argo application.
- Inspected the live VSO resources and destination secret.
- Fixed the executable bit on the validation script.
- Ran the end-to-end validation and confirmed rotation plus deny behavior.

### Why
- The live apply had to happen in dependency order: controller first, smoke CRs second.
- The deny probe is the quickest way to prove the policy boundary is narrow enough.

### What worked
- Both Argo applications reached `Synced Healthy`.
- `VaultConnection`, `VaultAuth`, and `VaultStaticSecret` all reported healthy and ready.
- The destination secret existed with the expected keys.
- Secret rotation propagated after the source value changed in Vault.

### What didn't work
- The first validation attempt failed because the script was not executable:
  - `zsh:1: permission denied: ./scripts/validate-vault-secrets-operator.sh`

### What I learned
- The live system behaved exactly the way the repo model predicted, which is a good sign that the abstraction boundary is clean.
- The in-cluster Vault address was the right first choice because there were no TLS or ingress distractions in the debug path.

### What was tricky to build
- The main operational subtlety was remembering that Argo reconciles from Git, so the scaffold had to be committed and pushed before I applied the live app objects.

### What warrants a second pair of eyes
- The current refresh interval is intentionally short for a smoke test. Review whether future real apps should standardize on a longer default.

### What should be done in the future
- Add a detailed operator guide for interns and future reviewers, then use this pattern for the first real application migration.

### Code review instructions
- Review:
  - [validate-vault-secrets-operator.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-vault-secrets-operator.sh)
  - [vault-static-secret.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-secrets-operator-smoke/vault-static-secret.yaml)
- Confirm the validation checks both allowed and denied behavior, not just destination secret creation.

### Technical details
- Notable live command outputs:
  - `vault kubernetes auth bootstrap complete`
  - `roles: 4`
  - `vault secrets operator validation passed`

## Step 4: Write the intern guide and prepare the ticket bundle for handoff

With the controller live and the smoke path validated, the remaining work in this ticket moved from platform changes to durable documentation. I added a long-form design and implementation guide at [01-vault-secrets-operator-architecture-and-implementation-guide.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0006--deploy-vault-secrets-operator-on-k3s-and-prove-secret-sync/design-doc/01-vault-secrets-operator-architecture-and-implementation-guide.md). The goal of that guide is to teach a new intern not only what files exist, but how the system actually works end to end: Argo reconciliation, Vault Kubernetes auth, the role/policy boundary, the VSO CRDs, and the runtime secret sync loop.

I also linked that guide from the ticket index, updated the task list and changelog to reflect the live rollout status, and prepared the bundle for `docmgr doctor` plus reMarkable upload. This is the point where the ticket turns from "implementation in progress" into "ready for another person to review and build on."

### What I did
- Added the long-form VSO architecture and implementation guide.
- Linked the guide from the ticket index.
- Updated the task list to mark live deployment and validation complete.
- Extended the changelog with the live rollout and documentation closeout.

### Why
- The next operator should not have to reconstruct the system from shell history and manifest diffs.
- This ticket is the template for future app migrations, so the explanation needs to be durable.

### What worked
- The design guide maps cleanly onto the actual files and runtime objects.
- The ticket now has the minimum durable artifacts for handoff: plan, diary, guide, tasks, and changelog.

### What didn't work
- My first patch attempt for the guide failed because `docmgr doc relate` had already changed the frontmatter, so I had to re-open the file and patch it against the updated state instead of the initial stub.

### What I learned
- `docmgr doc relate` is useful, but after it updates frontmatter you need to patch against the new exact file content.

### What was tricky to build
- The hardest part of the guide was keeping it intern-friendly without hiding the real security model.

### What warrants a second pair of eyes
- Review whether the guide is detailed enough for the first app-migration ticket, especially around how to extend the pattern beyond the smoke namespace.

### What should be done in the future
- Move on to the first real application migration now that the platform secret-delivery path is documented and proven.

## Step 5: Validate the ticket bundle and publish it to reMarkable

Once the guide and diary were in place, I ran the documentation validation and publication steps that turn this from a local work log into a durable handoff artifact. I ran:

```bash
docmgr doctor --ticket HK3S-0006 --stale-after 30
```

That returned a clean report with all checks passing. After that I used the `remarquee` bundle flow to publish the ticket materials as one PDF to the reMarkable path `/ai/2026/03/27/HK3S-0006`.

I dry-ran the bundle first to verify the exact inputs and output path, then ran the real upload. The bundle included:

- `index.md`
- `01-vault-secrets-operator-architecture-and-implementation-guide.md`
- `01-vault-secrets-operator-plan.md`
- `01-vault-secrets-operator-diary.md`

The final upload succeeded with:

```text
OK: uploaded HK3S-0006 Vault Secrets Operator Guide.pdf -> /ai/2026/03/27/HK3S-0006
```

I then verified the cloud listing and confirmed:

```text
[f] HK3S-0006 Vault Secrets Operator Guide
```

At that point the ticket had all the artifacts I wanted:

- plan
- guide
- diary
- tasks/changelog
- verified upload

### What I did
- Ran `docmgr doctor --ticket HK3S-0006 --stale-after 30`.
- Dry-ran the reMarkable bundle upload.
- Uploaded the final PDF bundle to `/ai/2026/03/27/HK3S-0006`.
- Verified the uploaded entry with `remarquee cloud ls`.

### Why
- A design ticket is not really finished until another person can discover, validate, and consume it without reconstructing the history themselves.

### What worked
- `docmgr doctor` passed without further metadata cleanup.
- `remarquee status` was already healthy.
- The bundle upload and cloud verification both succeeded.

### What didn't work
- The first `remarquee cloud ls` check ran before the upload finished and returned:
  - `Error: no matches for 'HK3S-0006'`

That was not a real failure. I simply polled too early while the upload was still in progress.

### What I learned
- The bundle workflow is a good default for ticket handoff because it creates one stable PDF instead of several loosely related uploads.

### What was tricky to build
- There was no real technical difficulty here beyond sequencing the verification after the upload completed.

### What warrants a second pair of eyes
- Review whether the bundle includes the right set of documents or whether future tickets should also include `tasks.md` directly.

### What should be done in the future
- Use the same bundle pattern for the first real application migration ticket so the operator handoff stays consistent.

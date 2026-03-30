---
Title: Investigation diary for release orchestration CLI design
Ticket: HK3S-0019
Status: complete
Topics:
    - gitops
    - argocd
    - ghcr
    - github
    - operations
    - kubernetes
    - cli
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../2026-03-30--pretext-wasm/.github/workflows/publish-trace-server-image.yaml
      Note: |-
        Source workflow used in the motivating scenario
        Exact workflow observed during the motivating rollout
    - Path: docs/app-packaging-and-gitops-pr-standard.md
      Note: |-
        Current standard for CI-created GitOps PRs
        Background playbook for CI-created GitOps PRs
    - Path: docs/source-app-deployment-infrastructure-playbook.md
      Note: |-
        Current operator playbook for the full deployment chain
        Background playbook referenced while mapping the current operator flow
    - Path: gitops/kustomize/pretext-trace/deployment.yaml
      Note: |-
        Concrete release target that exposed the operator workflow noise
        Concrete deployment that exposed rollout-state polling friction
    - Path: scripts/get-kubeconfig-tailscale.sh
      Note: |-
        Existing cluster auth helper exercised during the motivating rollout
        Exact cluster-access helper exercised during the motivating rollout
ExternalSources: []
Summary: Chronological diary for designing a CLI that compresses the source-to-GitOps release workflow into state-aware operator verbs.
LastUpdated: 2026-03-30T11:03:00-04:00
WhatFor: Use this to review the concrete commands, real pain points, and evidence that shaped the `hk3sctl` design.
WhenToUse: Read this when implementing the CLI or when checking which real-world release steps motivated the proposed command tree.
---


# Investigation diary for release orchestration CLI design

## Goal

Design a purpose-built operator CLI that reduces the number of separate tool calls and polling loops required for a normal source-to-GitOps release on this K3s platform.

## Context

The immediate trigger for this ticket was the `pretext-trace` deployment sequence. The platform architecture was working, but the operator had to manually bounce across:

- source Git history,
- GitHub Actions,
- GHCR,
- GitOps PRs,
- Argo reconciliation,
- Kubernetes rollout state,
- public auth and health verification,
- and Tailscale cluster access.

This diary records the exact commands and observations that made the need for a higher-level release CLI obvious.

## Step 1: Confirm the current deployment model is already documented, but too fragmented in practice

I started by re-reading the K3s repo’s deployment playbooks to make sure the problem was not simply missing documentation. It was not. The docs already explain the source-repo -> GHCR -> GitOps PR -> Argo CD flow clearly.

### What I did

- Read:
  - `docs/source-app-deployment-infrastructure-playbook.md`
  - `docs/app-packaging-and-gitops-pr-standard.md`
  - `docs/public-repo-ghcr-argocd-deployment-playbook.md`
- Re-checked the existing GitOps PR automation example in `mysql-ide`.

Commands run:

```bash
rg -n "gitops-targets|open_gitops_pr|GITOPS_PR_TOKEN|GitOps pull request" docs -S
sed -n '1,260p' docs/source-app-deployment-infrastructure-playbook.md
sed -n '1,260p' docs/app-packaging-and-gitops-pr-standard.md
sed -n '1,220p' /home/manuel/code/wesen/2026-03-27--mysql-ide/deploy/gitops-targets.json
sed -n '1,260p' /home/manuel/code/wesen/2026-03-27--mysql-ide/scripts/open_gitops_pr.py
sed -n '1,260p' /home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml
```

### What worked

- The docs were strong enough to show that the architecture itself was not the issue.
- The `mysql-ide` example confirmed that CI-created GitOps PRs are now part of the intended platform pattern.

### What didn’t work

- The docs do not remove the need to manually poll and correlate state across systems during a live release.

### What I learned

- The missing piece is orchestration, not more prose about the same flow.

## Step 2: Inventory the real command bursts from the `pretext-trace` rollout

I then treated the live `pretext-trace` rollout as the evidence set. The question was simple: what did the operator actually have to type, wait for, and compare manually?

### What I did

- Reviewed the recent source-repo workflow runs.
- Reviewed the automatically opened K3s PR.
- Verified GHCR image existence.
- Replayed the cluster checks and the public verification checks.

Commands that mattered:

```bash
gh run list -R wesen/2026-03-30--pretext-wasm --workflow publish-trace-server-image.yaml --limit 5
gh run view 23750576387 -R wesen/2026-03-30--pretext-wasm --json status,conclusion,jobs,url
docker manifest inspect ghcr.io/wesen/2026-03-30--pretext-wasm-trace-server:sha-36515c2

gh pr list -R wesen/2026-03-27--hetzner-k3s --limit 20
gh pr view 10 -R wesen/2026-03-27--hetzner-k3s --json title,body,headRefName,files,commits,url
gh pr diff 10 -R wesen/2026-03-27--hetzner-k3s
gh pr merge 10 -R wesen/2026-03-27--hetzner-k3s --merge --delete-branch

cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export K3S_TAILSCALE_DNS=k3s-demo-1.tail879302.ts.net
export K3S_TAILSCALE_IP=100.73.36.123
export K3S_TAILNET_KUBECONFIG=$PWD/.cache/kubeconfig-tailnet.yaml
./scripts/get-kubeconfig-tailscale.sh
export KUBECONFIG=$PWD/.cache/kubeconfig-tailnet.yaml

kubectl -n argocd annotate application pretext-trace argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd get application pretext-trace -o yaml
kubectl -n pretext-trace get deployment pretext-trace -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n pretext-trace rollout status deployment/pretext-trace --timeout=120s
kubectl -n pretext-trace get pods -o wide

curl -sS -u 'friend:trace-friends-2026' https://pretext-trace.yolo.scapegoat.dev/health
curl -sS -o /tmp/pretext-trace-health-noauth.txt -w '%{http_code}\n' https://pretext-trace.yolo.scapegoat.dev/health
curl -sS -u 'friend:trace-friends-2026' https://pretext-trace.yolo.scapegoat.dev/demos/assemblyscript-trace | rg -n "non-loopback host|127.0.0.1:3037"
```

### What worked

- Each individual command was the correct command for its own layer.
- The new source-repo workflow opened the GitOps PR automatically, which reduced one manual step.

### What didn’t work

- The operator still had to manually poll all the intermediate states.
- The public page could still serve the old pod briefly after rollout, which meant the operator had to reason about terminating pods and served content separately.

### What was tricky to build

- The hardest part was not one command failing. It was the need to correlate multiple “correct but partial” answers from different tools.

### What I learned

- The right abstraction is a release state machine, not another helper script for one layer.

## Step 3: Confirm the cluster-side pain includes access-path recovery, not just release-state polling

Another real source of friction was cluster access itself. At one point the local `kubectl` context was pointed at `kubernetes.docker.internal:6443`, which was wrong for this cluster. The actual recovery path was Tailscale.

### What I did

- Reused the documented Tailscale kubeconfig helper.
- Confirmed the cluster was reachable through the tailnet path.

Commands run:

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export K3S_TAILSCALE_DNS=k3s-demo-1.tail879302.ts.net
export K3S_TAILSCALE_IP=100.73.36.123
export K3S_TAILNET_KUBECONFIG=$PWD/.cache/kubeconfig-tailnet.yaml
./scripts/get-kubeconfig-tailscale.sh
export KUBECONFIG=$PWD/.cache/kubeconfig-tailnet.yaml
kubectl get nodes
```

### What worked

- The existing script and Tailscale docs solved the access problem cleanly.

### What didn’t work

- The operator still had to remember that the access problem existed and manually re-run the right recovery steps.

### What I learned

- The CLI should not just know “how to release.”
- It should also know “how to obtain cluster visibility” for targets that use the Tailscale admin path.

## Step 4: Compare existing automation against the missing abstraction

At this point I compared what already exists against what is still missing.

### Existing automation that already works

- Source workflow publishes immutable GHCR images.
- Source workflow opens a GitOps PR.
- GitOps repo owns the Deployment image pin.
- Argo CD watches the GitOps repo.
- Kubernetes rolls the Deployment.
- Traefik and curl-based verification are already simple enough.

### What is still missing

- one operator command that spans all of those states,
- a shared target registry for release metadata,
- a bounded waiting model for state transitions,
- a single summary view for “where is this release currently blocked?”

### What I learned

- The CLI should integrate the existing system, not replace it.

## Step 5: Choose the implementation stance

The next design choice was whether the new CLI should be:

- more shell,
- a Python wrapper,
- or a compiled tool.

I chose a compiled Go CLI with subprocess adapters in phase 1.

### Why

- Go gives us a durable binary and structured concurrency.
- This repo already tolerates Go code, even though most operator helpers are shell.
- We can shell out to `gh`, `kubectl`, `git`, `curl`, and existing repo scripts first, then selectively replace polling with native clients later.

### Why not shell-only

- The problem is already too orchestration-heavy for shell to stay pleasant.

### Why not native APIs only from day one

- That would slow phase 1 down and duplicate already-working tools.

## Quick Reference

### Proposed CLI name

```text
hk3sctl
```

### Proposed high-value verbs

```text
release plan
release run
release status
release wait
release verify
release rollback
```

### Proposed target file shape

```yaml
name: pretext-trace
source_repo:
  github_repo: wesen/2026-03-30--pretext-wasm
  workflow: publish-trace-server-image.yaml
  image_repository: ghcr.io/wesen/2026-03-30--pretext-wasm-trace-server
gitops:
  github_repo: wesen/2026-03-27--hetzner-k3s
  manifest_path: gitops/kustomize/pretext-trace/deployment.yaml
  argo_application: pretext-trace
cluster:
  namespace: pretext-trace
  deployment: pretext-trace
verify:
  health_url: https://pretext-trace.yolo.scapegoat.dev/health
```

### Proposed first implementation phases

1. `release plan` and `release status`
2. `release wait`
3. `release run`
4. native API replacements for the most painful polling loops

## Usage Examples

### Example 1: See everything that matters for one release target

```bash
hk3sctl release status pretext-trace
```

Expected responsibilities:

- show source HEAD,
- show CI status,
- show latest image tag,
- show GitOps PR state,
- show Deployment image,
- show rollout state,
- show public verification status.

### Example 2: Wait only for the next state

```bash
hk3sctl release wait pretext-trace --for rollout --timeout 10m
```

This should replace repeated manual `kubectl rollout status` and `kubectl get deployment ... image` calls.

### Example 3: Run the full happy path

```bash
hk3sctl release run pretext-trace --push-source --merge-pr --wait --verify
```

That command should still preserve all the underlying boundaries, but it should keep the operator in one place while doing it.

## What warrants a second pair of eyes

- Whether the CLI should live in this repo long-term or start here and later move to a dedicated operator-tools repo.
- Whether PR merge should remain opt-in.
- Whether infra-side release target metadata should be YAML under `releases/targets/` or a different registry layout.

## Code review instructions

Review the design doc and confirm that every major recommendation is grounded in an actual release pain point rather than a hypothetical abstraction problem.

Then compare the motivating commands in this diary against:

- `docs/source-app-deployment-infrastructure-playbook.md`
- `docs/app-packaging-and-gitops-pr-standard.md`
- `scripts/get-kubeconfig-tailscale.sh`
- `gitops/applications/pretext-trace.yaml`
- `gitops/kustomize/pretext-trace/deployment.yaml`

The design is correct only if it clearly reduces operator polling without breaking the existing control-plane boundaries.

## Related

- `ttmp/2026/03/28/HK3S-0013--automate-gitops-image-bumps-and-standardize-app-packaging-layout/`
- `docs/source-app-deployment-infrastructure-playbook.md`
- `docs/app-packaging-and-gitops-pr-standard.md`
- `docs/tailscale-k3s-admin-access-playbook.md`

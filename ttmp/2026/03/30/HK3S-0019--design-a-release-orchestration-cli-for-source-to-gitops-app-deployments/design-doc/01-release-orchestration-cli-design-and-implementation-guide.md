---
Title: Release orchestration CLI design and implementation guide
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
DocType: design-doc
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../2026-03-30--pretext-wasm/.github/workflows/publish-trace-server-image.yaml
      Note: |-
        Source-repo workflow now publishes the image and opens the GitOps PR
        Source workflow that now publishes the image and opens the GitOps PR
    - Path: ../../../../../../../2026-03-30--pretext-wasm/scripts/open_gitops_pr.py
      Note: |-
        Existing source-repo updater logic that the CLI should integrate with rather than duplicate blindly
        Existing source-repo updater logic the CLI should understand rather than duplicate blindly
    - Path: docs/app-packaging-and-gitops-pr-standard.md
      Note: |-
        Current CI-created GitOps PR pattern the CLI should understand rather than replace
        Current CI-created GitOps PR standard the CLI should integrate with
    - Path: docs/source-app-deployment-infrastructure-playbook.md
      Note: |-
        Canonical source-app to GitOps deployment model this CLI needs to compress
        Canonical deployment model this CLI compresses operationally
    - Path: gitops/applications/pretext-trace.yaml
      Note: |-
        Argo application reference for a real release target
        Real Argo application target used in the motivating scenario
    - Path: gitops/kustomize/pretext-trace/deployment.yaml
      Note: |-
        Real GitOps image pin and rollout target for the motivating scenario
        Real rollout target and image pin used in the motivating scenario
    - Path: scripts/get-kubeconfig-tailscale.sh
      Note: |-
        Existing cluster-admin path resolver the CLI should reuse in phase 1
        Existing cluster-access helper to reuse in phase 1
ExternalSources: []
Summary: Detailed design guide for a single operator CLI that collapses the multi-repo, multi-tool source-to-GitOps deployment workflow into a state-aware release interface.
LastUpdated: 2026-03-30T11:03:00-04:00
WhatFor: Use this when deciding how to replace ad hoc release polling and cross-repo command juggling with a purpose-built operator CLI.
WhenToUse: Read this before implementing a release orchestration CLI, extending the GitOps PR flow, or standardizing app release operations in the K3s platform.
---


# Release orchestration CLI design and implementation guide

## Executive Summary

The current K3s deployment model is correct in architecture but noisy in operation. A single real release for `pretext-trace` required switching across:

- a source repository,
- GitHub Actions,
- GHCR,
- the GitOps repository,
- Argo CD,
- Kubernetes rollout state,
- Traefik ingress and auth,
- public health verification,
- and the Tailscale admin path when live cluster confirmation was needed.

The system is not wrong. It is simply spread across too many tools and too many polling loops for routine use. The same release required repeated use of:

```bash
gh run list
gh run view
docker manifest inspect
gh pr list
gh pr view
gh pr diff
gh pr merge
./scripts/get-kubeconfig-tailscale.sh
kubectl -n argocd annotate application ... refresh=hard
kubectl -n <ns> rollout status deployment/<name>
kubectl -n <ns> get deployment <name> -o jsonpath=...
curl -u 'user:pass' https://.../health
```

This ticket proposes a purpose-built operator CLI, tentatively named `hk3sctl`, that keeps the existing control-plane boundaries but compresses the operational surface into a small set of state-aware verbs:

- `release plan`
- `release run`
- `release status`
- `release wait`
- `release verify`
- `release rollback`

The core design decision is important:

- do not replace GitHub Actions, GitOps PRs, Argo CD, or Kubernetes
- instead, create one CLI that understands their relationships and waits on meaningful state transitions

In phase 1, the CLI should shell out to existing tools and scripts where they are already the source of truth. In phase 2, it can replace the highest-value polling loops with native GitHub and Kubernetes clients. This keeps the first implementation small, pragmatic, and consistent with the current repo.

## Problem Statement

The K3s platform already has a documented deployment model:

```text
source repo
  -> CI build and publish
  -> immutable GHCR image
  -> GitOps PR
  -> merged GitOps desired state
  -> Argo sync
  -> Kubernetes rollout
  -> ingress / public verification
```

The problem is not conceptual. It is operational.

The real release path still forces an operator to manually coordinate several independent tools and mental models:

1. Git history and source-repo branch state.
2. GitHub Actions run status.
3. Registry artifact existence.
4. GitOps PR creation and merge state.
5. Argo application sync and revision state.
6. Kubernetes deployment rollout status.
7. Public ingress and auth verification.
8. Tailscale kubeconfig recovery when local `kubectl` is pointed at the wrong cluster.

### The concrete trigger

The `pretext-trace` rollout exposed this sharply. To update one browser-side bug fix, the operator path looked like this:

1. Push a source-repo commit.
2. Wait for the source workflow to publish a new image.
3. Verify the image tag exists in GHCR.
4. Wait for or inspect the CI-created GitOps PR.
5. Review and merge that PR.
6. Verify Argo has seen the new GitOps revision.
7. Verify the Deployment spec is updated to the new image.
8. Wait for rollout completion.
9. Recheck the live page content because the old pod may still be serving.

Each step is individually reasonable. Taken together, they produce too much operator chatter and too many manual polling loops.

### Real command sequences that motivated this design

The following were all used in one live deployment and verification session:

```bash
gh run list -R wesen/2026-03-30--pretext-wasm --workflow publish-trace-server-image.yaml --limit 5
gh run view 23750576387 -R wesen/2026-03-30--pretext-wasm --json status,conclusion,jobs,url
docker manifest inspect ghcr.io/wesen/2026-03-30--pretext-wasm-trace-server:sha-36515c2

gh pr list -R wesen/2026-03-27--hetzner-k3s --limit 20
gh pr view 10 -R wesen/2026-03-27--hetzner-k3s --json title,body,files,commits,url
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

The design goal is not to hide these facts. The goal is to make one tool aware of them so the operator no longer has to keep typing and polling them manually.

## Current System Architecture

### Control planes already present

The current K3s platform separates responsibilities correctly:

```text
source repo
  -> build/test/publish image
  -> optionally open GitOps PR

GitOps repo
  -> pin image in manifest
  -> own namespace / ingress / secrets / Argo Application

cluster
  -> run Argo CD
  -> reconcile manifests
  -> roll Deployment
  -> expose public endpoint
```

Evidence:

- `docs/source-app-deployment-infrastructure-playbook.md`
- `docs/app-packaging-and-gitops-pr-standard.md`
- `gitops/applications/pretext-trace.yaml`
- `gitops/kustomize/pretext-trace/deployment.yaml`

### Existing automation pieces the CLI should reuse

The platform already has useful building blocks:

1. Source-repo image publication and GitOps PR automation.
2. GitOps manifests and Argo Applications.
3. Tailscale kubeconfig acquisition script.
4. Public ingress verification by `curl`.
5. Existing `gh`, `kubectl`, `docker`, and `git` based operator habits.

Those are not waste. They are the substrate the CLI should sit on top of in phase 1.

### Existing gaps

The missing component is an orchestration layer that can answer questions like:

- What is the latest source commit for target `pretext-trace`?
- Has CI for that commit succeeded?
- Does the corresponding GHCR image exist?
- Is there already a GitOps PR for it?
- Has that PR been merged?
- Has Argo reconciled the new GitOps revision?
- Has the Deployment rolled to the new image?
- Is the public route healthy with and without auth?

Today the operator answers these by hand.

## Design Goals

The CLI should:

1. Preserve the current architecture.
2. Reduce polling loops and copy-paste command bursts.
3. Make state transitions explicit.
4. Fail fast at the correct boundary.
5. Reuse existing repo conventions instead of inventing parallel ones.
6. Work well for a new intern who does not yet know how all the tools fit together.

The CLI should not:

1. replace GitHub Actions with local release logic,
2. replace Argo CD with direct `kubectl apply`,
3. hide immutable image tags,
4. silently fall back to local workarounds when the documented release contract is broken.

That last rule is especially important because the K3s docs now explicitly say that if GHCR publication through GitHub CI fails, the operator should stop and ask for guidance rather than improvise a local workaround.

## Proposed Solution

### Name and scope

The proposed tool is `hk3sctl`.

It is an operator CLI for release orchestration across:

- source repository state,
- CI status,
- image registry state,
- GitOps PR state,
- Argo CD application state,
- Kubernetes rollout state,
- ingress and auth verification,
- Tailscale kubeconfig acquisition when cluster inspection is needed.

### Core idea

The CLI should model a release as a state machine rather than a pile of commands.

```text
planned
  -> source pushed
  -> ci green
  -> image published
  -> gitops pr open
  -> gitops pr merged
  -> argo reconciled
  -> rollout complete
  -> public verification passed
```

Instead of repeatedly polling separate tools, the CLI should expose verbs that wait on these states directly.

### Recommended top-level verbs

#### `release`

Primary high-value command group.

- `release plan <target>`
- `release run <target>`
- `release status <target>`
- `release wait <target> --for <state>`
- `release verify <target>`
- `release rollback <target> --to <image-tag>`

#### `source`

Focused source-repo helpers.

- `source push <target>`
- `source ci status <target>`
- `source ci logs <target>`
- `source image ls <target>`
- `source image inspect <target> --tag sha-...`

#### `gitops`

PR and manifest helpers.

- `gitops bump <target> --image ...`
- `gitops pr open <target>`
- `gitops pr status <target>`
- `gitops pr merge <target>`
- `gitops diff <target>`

#### `cluster`

Cluster access and state helpers.

- `cluster auth ensure`
- `cluster app status <target>`
- `cluster app refresh <target>`
- `cluster rollout status <target>`
- `cluster pod images <target>`
- `cluster logs <target>`

#### `verify`

Public endpoint and auth helpers.

- `verify health <target>`
- `verify auth <target>`
- `verify served-content <target>`

### Recommended target registry

The CLI needs one infra-side registry of release targets so operators do not keep reconstructing the workflow from memory.

Recommended file shape:

```yaml
# releases/targets/pretext-trace.yaml
name: pretext-trace
source_repo:
  path: /home/manuel/code/wesen/2026-03-30--pretext-wasm
  github_repo: wesen/2026-03-30--pretext-wasm
  workflow: publish-trace-server-image.yaml
  image_repository: ghcr.io/wesen/2026-03-30--pretext-wasm-trace-server
  gitops_targets_file: deploy/gitops-targets.json
gitops:
  repo_path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s
  github_repo: wesen/2026-03-27--hetzner-k3s
  manifest_path: gitops/kustomize/pretext-trace/deployment.yaml
  argo_application: pretext-trace
cluster:
  namespace: pretext-trace
  deployment: pretext-trace
  container: pretext-trace
  kubeconfig_strategy: tailscale
verify:
  health_url: https://pretext-trace.yolo.scapegoat.dev/health
  page_url: https://pretext-trace.yolo.scapegoat.dev/demos/assemblyscript-trace
  auth:
    mode: basic
    username_env: PRETEXT_TRACE_BASIC_AUTH_USER
    password_env: PRETEXT_TRACE_BASIC_AUTH_PASSWORD
```

This is intentionally infra-centric. The source repo still keeps its own `deploy/gitops-targets.json` for CI-created PRs, but the operator CLI should keep one cluster-side registry that knows how to inspect and verify the full path.

### Why an infra-side target registry is worth it

Because the K3s repo is the operator source of truth for:

- Argo application names,
- namespaces,
- deployment names,
- ingress URLs,
- auth modes,
- Tailscale-based cluster access.

The source repo should not have to know all of that.

## Key Design Decisions

### Decision 1: Use a compiled Go CLI, not more shell glue

Recommendation:

- implement `hk3sctl` in Go
- use a conventional command tree, likely Cobra
- emit both human-readable and JSON output

Why:

- a static binary is easier to ship than a larger shell script web
- Go handles subprocess orchestration, retries, timeouts, and structured output well
- native Kubernetes and GitHub clients are available for later phases

Why not shell-only:

- shell is fine for focused helpers like `get-kubeconfig-tailscale.sh`
- shell is weak for a long-running multi-state orchestration CLI with structured status output

Why not require Glazed on day one:

- it would increase initial scope
- the immediate value is orchestration, not output styling
- Glazed compatibility can be added later if the team wants standardized tables/forms/JSON

### Decision 2: Shell out in phase 1 where the tool boundary is already stable

Phase 1 should still call:

- `git`
- `gh`
- `kubectl`
- `curl`
- `docker manifest inspect`
- `./scripts/get-kubeconfig-tailscale.sh`

Why:

- those tools are already part of the real operator contract
- they are already documented in the repo
- replacing them all at once would make the first implementation too large

The CLI should act like a stateful orchestrator over stable tools first, not like a clean-room rewrite.

### Decision 3: Native clients only where they remove real polling pain

The biggest polling pain today is:

- repeated `gh run view`
- repeated `gh pr list`
- repeated `kubectl get deployment ... image`
- repeated `kubectl rollout status`

So later phases should replace those first with:

- GitHub Actions/PR API calls or `gh api`
- Kubernetes typed clients or watches

The goal is fewer polling loops, not ideological purity.

### Decision 4: The CLI must encode failure boundaries explicitly

Example:

- if CI did not publish the image, the CLI should stop at `image missing`
- it should not silently patch GitOps to an old tag
- it should not suggest a node-local image import unless the operator asked for an emergency path

This follows the existing K3s playbooks, which now explicitly treat local workaround publishing as an exception.

## Command Semantics

### `release plan`

Shows the intended release graph without mutating anything.

Example:

```bash
hk3sctl release plan pretext-trace
```

Expected output shape:

```text
target: pretext-trace
source repo: wesen/2026-03-30--pretext-wasm
workflow: publish-trace-server-image.yaml
image repo: ghcr.io/wesen/2026-03-30--pretext-wasm-trace-server
gitops repo: wesen/2026-03-27--hetzner-k3s
manifest: gitops/kustomize/pretext-trace/deployment.yaml
argo app: pretext-trace
deployment: pretext-trace/pretext-trace
verify: basic-auth /health + page content
```

### `release status`

Aggregates all current state in one place.

Example:

```bash
hk3sctl release status pretext-trace
```

It should gather:

- current source HEAD
- latest successful workflow run for that HEAD
- image existence
- open GitOps PR, if any
- current Argo revision
- current Deployment image
- rollout completeness
- public health/auth verification result

### `release run`

Orchestrates the happy path.

Example:

```bash
hk3sctl release run pretext-trace --push-source --merge-pr --wait --verify
```

Suggested internal flow:

```text
resolve target
-> optionally push source repo
-> wait for CI success
-> verify image exists
-> wait for GitOps PR or open it if this repo owns that step
-> optionally merge PR
-> ensure cluster auth path
-> wait for Argo revision to change
-> wait for Deployment rollout
-> verify auth and public health
-> print final release report
```

### `release wait`

This is the direct answer to the “too many polling loops” problem.

Example:

```bash
hk3sctl release wait pretext-trace --for image
hk3sctl release wait pretext-trace --for pr-merged
hk3sctl release wait pretext-trace --for rollout
hk3sctl release wait pretext-trace --for public-ok
```

Each state should map to a bounded wait with informative progress output.

### `release verify`

Runs the final user-facing checks only.

Example:

```bash
hk3sctl release verify pretext-trace
```

Checks:

- unauthenticated `/health` returns `401`
- authenticated `/health` returns `200`
- served page content matches the expected image behavior

## API And Data References

### GitHub Actions

Current source of truth:

- `gh run list`
- `gh run view`

Later native API candidate:

- `GET /repos/{owner}/{repo}/actions/runs`
- `GET /repos/{owner}/{repo}/actions/runs/{run_id}`

Fields the CLI actually needs:

- run status
- conclusion
- head SHA
- workflow name
- run URL

### GitHub Pull Requests

Current source of truth:

- `gh pr list`
- `gh pr view`
- `gh pr diff`
- `gh pr merge`

Fields the CLI actually needs:

- PR number
- title
- head branch
- merge state
- changed files

### Kubernetes / Argo

Relevant data already visible in this repo and cluster:

- `gitops/applications/pretext-trace.yaml`
- `kubectl -n argocd get application pretext-trace -o yaml`
- `kubectl -n pretext-trace get deployment pretext-trace -o jsonpath=...`

Fields the CLI actually needs:

- Argo application revision
- Argo health and sync status
- Deployment desired image
- updated/ready replicas
- rollout completion

### Public verification

Current pattern:

```bash
curl -u user:pass https://.../health
curl https://.../health
curl -u user:pass https://.../page | rg ...
```

The CLI should preserve this simplicity. It does not need a browser engine for v1.

## Alternatives Considered

### Alternative 1: Keep using individual commands and improve docs only

Rejected because:

- the docs are already fairly good
- the problem is execution friction, not missing theory
- the same polling loops will keep happening

### Alternative 2: Let the source repo own the entire release

Rejected because:

- the GitOps repo remains the deployment source of truth
- cluster-side verification and auth live here
- Argo watches this repo, not the source repo

### Alternative 3: Use Argo CD Image Updater instead of explicit GitOps PRs

Rejected for now because:

- it adds another controller and another mental model
- explicit PR review remains easier to understand and roll back
- it solves only the image-bump part, not the wider orchestration problem

### Alternative 4: Build the CLI entirely around native APIs from day one

Rejected for v1 because:

- it would duplicate existing, working tooling too early
- phase 1 can ship faster by orchestrating existing commands
- the highest-value native integrations are specific and can be phased

## Detailed Implementation Plan

### Phase 1: Skeleton and target registry

Create a new Go module for the CLI, preferably isolated from the demo app.

Recommended layout:

```text
tools/hk3sctl/
  go.mod
  main.go
  cmd/
    root.go
    release.go
    source.go
    gitops.go
    cluster.go
    verify.go
  internal/
    targets/
    execx/
    githubx/
    kubex/
    verifyx/
```

Also add:

```text
releases/targets/
  pretext-trace.yaml
  mysql-ide.yaml
```

Implementation steps:

1. Load one target file.
2. Resolve paths and environment.
3. Implement `release plan`.
4. Implement `release status` via subprocess adapters.

### Phase 2: Wait primitives

Add bounded waiters:

- wait for workflow success
- wait for image existence
- wait for GitOps PR state
- wait for Argo revision
- wait for rollout completion
- wait for public verification

Important implementation detail:

- centralize retry intervals and timeouts
- avoid open-coded `for` loops in every command

Pseudocode:

```go
func WaitUntil(ctx context.Context, name string, check func(context.Context) (State, error)) error {
    ticker := time.NewTicker(3 * time.Second)
    defer ticker.Stop()
    for {
        state, err := check(ctx)
        if err != nil {
            return err
        }
        if state.Done {
            return nil
        }
        select {
        case <-ctx.Done():
            return fmt.Errorf("%s did not complete before timeout", name)
        case <-ticker.C:
        }
    }
}
```

### Phase 3: Release orchestration

Implement `release run`.

Suggested execution policy:

- require explicit flags for mutations
- default to plan/status unless the user opts into mutation

Example:

```bash
hk3sctl release run pretext-trace \
  --push-source \
  --merge-pr \
  --wait \
  --verify
```

Each mutation step should log:

- what it is doing,
- why it is doing it,
- what exact external command or API call it used,
- what state it is waiting for next.

### Phase 4: Native integrations where justified

After the shell-out version is trusted:

1. Replace some `gh` polling with GitHub API calls.
2. Replace some `kubectl get` polling with Kubernetes client-go watches.
3. Keep `git` and `curl` subprocess use if they remain simpler than rewriting.

### Phase 5: Broaden target coverage

Support at least:

- `pretext-trace`
- `mysql-ide`
- one private-image app such as `draft-review` or `coinvault`

This matters because the CLI should prove it handles:

- public GHCR image path,
- CI-created GitOps PR path,
- Tailscale cluster verification path,
- auth-protected public verification path.

## Validation Strategy

### Local validation

The CLI should support dry-run and status-only checks that do not mutate anything.

Examples:

```bash
hk3sctl release plan pretext-trace
hk3sctl release status pretext-trace --output json
hk3sctl release wait pretext-trace --for image --timeout 5m
```

### Integration validation

The first real validation should replay a workflow like this:

1. make a trivial source change,
2. push source,
3. let CI publish an image,
4. let CI open the GitOps PR,
5. have the CLI detect and merge the PR,
6. have the CLI wait through Argo and rollout,
7. have the CLI verify public health.

That is exactly the operator path this design is meant to compress.

### Failure-mode validation

Prove these cases:

- CI run failed
- image tag missing
- no GitOps PR opened
- Argo revision stale
- rollout stuck
- auth check failed
- local `kubectl` using the wrong kubeconfig

The last case is especially important because this repo already has a documented and working recovery path through `scripts/get-kubeconfig-tailscale.sh`.

## Risks And Tradeoffs

### Risk: The CLI becomes an opaque “magic deploy button”

Mitigation:

- keep each state visible
- keep subcommands inspectable
- support `--output json`
- print the underlying command/API activity in verbose mode

### Risk: Too much scope in v1

Mitigation:

- shell out to stable tools first
- do not rewrite every API on day one
- ship `plan`, `status`, `wait`, and `verify` before a fully mutating `run`

### Risk: Target metadata drifts from source repos

Mitigation:

- keep the target registry intentionally small
- validate paths and repo IDs on every run
- cross-check against source-repo `deploy/gitops-targets.json` where present

## Open Questions

1. Should the CLI live in this repo long-term, or only start here and later move to its own operator-tools repo?
2. Should PR merge remain opt-in forever, or become a normal part of `release run`?
3. Should the CLI own basic-auth credentials lookup, or should verification always use explicit environment variables?
4. When native GitHub and Kubernetes clients are added, which shell-outs remain intentionally external?

## References

- `docs/source-app-deployment-infrastructure-playbook.md`
- `docs/app-packaging-and-gitops-pr-standard.md`
- `docs/tailscale-k3s-admin-access-playbook.md`
- `docs/traefik-simple-auth-playbook.md`
- `gitops/applications/pretext-trace.yaml`
- `gitops/kustomize/pretext-trace/deployment.yaml`
- `/home/manuel/code/wesen/2026-03-30--pretext-wasm/.github/workflows/publish-trace-server-image.yaml`
- `/home/manuel/code/wesen/2026-03-30--pretext-wasm/scripts/open_gitops_pr.py`

## Proposed Solution

<!-- Describe the proposed solution in detail -->

## Design Decisions

<!-- Document key design decisions and rationale -->

## Alternatives Considered

<!-- List alternative approaches that were considered and why they were rejected -->

## Implementation Plan

<!-- Outline the steps to implement this design -->

## Open Questions

<!-- List any unresolved questions or concerns -->

## References

<!-- Link to related documents, RFCs, or external resources -->

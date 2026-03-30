---
Title: JavaScript release automation runtime design and implementation guide
Ticket: HK3S-0020
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
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/source-app-deployment-infrastructure-playbook.md
      Note: Canonical deployment model that the JavaScript runtime will automate
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/app-packaging-and-gitops-pr-standard.md
      Note: Existing CI-created GitOps PR contract the runtime must respect
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/get-kubeconfig-tailscale.sh
      Note: Current cluster-access helper the first runtime implementation can wrap
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/pretext-trace.yaml
      Note: Concrete Argo application used throughout the motivating scenario
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/pretext-trace/deployment.yaml
      Note: Concrete GitOps release target and rollout object
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/30/HK3S-0019--design-a-release-orchestration-cli-for-source-to-gitops-app-deployments/design-doc/01-release-orchestration-cli-design-and-implementation-guide.md
      Note: Sibling ticket covering the command-oriented alternative
    - Path: /home/manuel/code/wesen/2026-03-30--pretext-wasm/.github/workflows/publish-trace-server-image.yaml
      Note: Source-repo workflow used in the motivating scenario
ExternalSources: []
Summary: "Detailed design guide for a JavaScript automation runtime that exposes source, GitOps, registry, cluster, and verification subsystems as programmable APIs for release snippets."
LastUpdated: 2026-03-30T11:18:00-04:00
WhatFor: "Use this when designing a programmable alternative to a fixed CLI for K3s release operations."
WhenToUse: "Read this before implementing a JS SDK or REPL-driven automation runtime for source-to-GitOps deployments."
---

# JavaScript release automation runtime design and implementation guide

## Executive Summary

HK3S-0019 proposed a release-oriented CLI with verbs like `release run` and `release verify`. This ticket proposes the programmable sibling to that design: a JavaScript or TypeScript runtime that exposes the same release graph as stable APIs.

The motivation is practical. Many real operator tasks are not standardized enough to deserve permanent CLI verbs, but they are still regular enough to deserve first-class APIs and built-in waiters. Examples:

- merge a GitOps PR only if the diff is exactly one image-line change,
- wait for rollout, then inspect served HTML for a marker string,
- skip cluster auth if the public verification already proves success,
- or compare desired and actual Deployment images before merging.

Those tasks are clumsy as shell transcripts and too custom for a permanent command tree. They are natural as short JS snippets.

This design recommends:

- a TypeScript-first library,
- a stable target registry,
- subsystem APIs for source, registry, GitOps, Argo, cluster, and verification,
- built-in waiters and structured return values,
- and a lightweight snippet runner layered on top.

The runtime is not meant to replace GitHub Actions, Argo CD, or GitOps PRs. It is meant to make them programmable.

## Problem Statement

The K3s platform already has the right architecture:

```text
source repo
  -> CI build and publish
  -> immutable GHCR image
  -> GitOps PR
  -> merged desired state
  -> Argo sync
  -> Kubernetes rollout
  -> public ingress verification
```

The problem is the operational surface around that architecture.

During the `pretext-trace` release, the operator still had to manually coordinate:

- source-repo Git state,
- GitHub Actions workflow state,
- GHCR image existence,
- GitOps PR state and diff,
- Argo application state,
- Kubernetes rollout state,
- Tailscale-based cluster access,
- public auth and health verification,
- and served page-content checks.

That produced a long burst of tool-specific commands:

```bash
gh run list ...
gh run view ...
docker manifest inspect ...
gh pr list ...
gh pr diff ...
gh pr merge ...
./scripts/get-kubeconfig-tailscale.sh
kubectl -n argocd annotate application ... refresh=hard
kubectl -n pretext-trace rollout status deployment/pretext-trace --timeout=120s
curl -u ... https://.../health
curl -u ... https://.../demos/assemblyscript-trace | rg ...
```

The missing abstraction is not “a better shell alias.” It is a programmable runtime that knows what those systems mean and can expose them as composable objects and waiters.

## Current System Architecture

### Existing control planes

The runtime must respect the current platform boundaries:

```text
source repo
  -> owns source code, tests, Dockerfile, publish workflow

GitOps repo
  -> owns Deployment image pin, Argo Application, ingress, auth, and rollout topology

cluster
  -> owns Argo reconciliation, pod lifecycle, rollout state, and public serving
```

This is already documented in:

- `docs/source-app-deployment-infrastructure-playbook.md`
- `docs/app-packaging-and-gitops-pr-standard.md`
- `gitops/applications/pretext-trace.yaml`
- `gitops/kustomize/pretext-trace/deployment.yaml`

The runtime should not blur those boundaries. It should make them easier to navigate.

### Existing automation pieces the runtime can reuse

The platform already provides useful helpers and conventions:

1. Source workflows that publish images and open GitOps PRs.
2. GitOps manifests that pin immutable image SHAs.
3. Tailscale kubeconfig acquisition via `scripts/get-kubeconfig-tailscale.sh`.
4. Public verification via simple HTTP checks.
5. `gh`, `kubectl`, `docker`, and `git` as stable operator-facing tools.

That means the runtime does not need to be a clean-room rewrite in phase 1. It can wrap the existing, real control-plane surfaces first.

## Proposed Solution

### Runtime model

Build a JS or TS runtime with:

1. a target registry,
2. runtime context creation,
3. subsystem clients,
4. state-aware waiters,
5. a snippet runner or REPL integration,
6. structured results.

The conceptual flow is:

```text
target name
  -> target metadata
    -> runtime context
      -> subsystem clients
        -> JS snippet
          -> structured result / failure / release report
```

### Recommended package layout

```text
packages/hk3s-runtime/
  package.json
  tsconfig.json
  src/
    index.ts
    targets/
    context/
    source/
    registry/
    gitops/
    argo/
    cluster/
    verify/
    wait/
    auth/
    runner/
```

Also add:

```text
releases/targets/
  pretext-trace.yaml
  mysql-ide.yaml
```

### Public API shape

```ts
import {
  releases,
  source,
  registry,
  gitops,
  argo,
  cluster,
  verify,
  release,
} from "@wesen/hk3s-runtime";
```

### Core subsystem APIs

#### `releases`

Loads and validates target metadata.

```ts
const target = await releases.getTarget("pretext-trace");
```

Suggested target type:

```ts
type ReleaseTarget = {
  name: string;
  sourceRepo: {
    path: string;
    githubRepo: string;
    workflow: string;
    imageRepository: string;
    gitopsTargetsFile?: string;
  };
  gitopsRepo: {
    path: string;
    githubRepo: string;
    manifestPath: string;
  };
  cluster: {
    namespace: string;
    deployment: string;
    container: string;
    argoApplication: string;
    kubeconfigStrategy: "tailscale" | "local";
  };
  verify: {
    healthUrl: string;
    pageUrl?: string;
    auth?: {
      mode: "basic";
      usernameEnv: string;
      passwordEnv: string;
    };
  };
};
```

#### `source`

Wraps local Git and source-repo CI state.

```ts
await source.git(target).status();
await source.git(target).pushCurrentBranch();
await source.github(target).latestWorkflowRun();
await source.github(target).waitForWorkflowRun({ workflow, sha });
```

#### `registry`

Wraps registry existence and metadata checks.

```ts
await registry.ghcr().hasImage(imageRef);
await registry.ghcr().waitForImage(imageRef);
await registry.ghcr().inspect(imageRef);
```

#### `gitops`

Wraps PR lifecycle and GitOps diff/merge state.

```ts
await gitops.repo(target).findOpenImagePr({ image });
await gitops.repo(target).waitForOrCreateImageBumpPr({ image });
await gitops.repo(target).diffPr(pr.number);
await gitops.repo(target).mergePr(pr.number);
```

#### `argo`

Wraps Argo application state.

```ts
await argo.app(target).status();
await argo.app(target).refresh();
await argo.app(target).waitForRevision(revision);
await argo.app(target).waitForHealthy();
```

#### `cluster`

Wraps cluster auth and rollout state.

```ts
await cluster.auth("tailscale").ensure();
await cluster.deployment(target).getImage();
await cluster.deployment(target).waitForRollout();
await cluster.pods(target).list();
```

#### `verify`

Wraps public health, auth, and page-content checks.

```ts
await verify.http(target).expectBasicAuthChallenge();
await verify.http(target).expectHealthOk();
await verify.page(target).fetchHtml();
await verify.page(target).expectText("non-loopback host");
```

#### `release`

Provides composed helpers, but still as library calls rather than a fixed CLI tree.

```ts
await release.status(target);
await release.wait(target, "rollout");
await release.run(target, { mergePr: true, verify: true });
```

## Design Decisions

### Decision 1: Library first, runner second

The main artifact should be a library, not a command binary with a different coat of paint.

Why:

- the value is composability,
- snippets need stable objects and functions,
- and the most useful workflows are not all known ahead of time.

### Decision 2: Use TypeScript

The runtime should be authored in TypeScript and emitted as JavaScript.

Why:

- target metadata is cross-cutting and easy to get wrong,
- structured results matter,
- this runtime is about stateful automation, not quick one-off scripting only.

### Decision 3: Wrap stable existing tools in phase 1

The first implementation should still use:

- `git`
- `gh`
- `docker manifest inspect`
- `kubectl`
- `curl`
- `scripts/get-kubeconfig-tailscale.sh`

Why:

- they are already the real operator surface,
- they are already documented,
- replacing all of them at once would inflate scope dramatically.

### Decision 4: Waiters should be first-class

The runtime should not make the user write polling loops manually.

Bad:

```js
while (true) {
  const run = await readRun();
  if (run.done) break;
  await sleep(3000);
}
```

Good:

```js
await source.github(target).waitForWorkflowRun({ workflow, sha });
```

### Decision 5: The runtime and the CLI are complementary

HK3S-0019 and HK3S-0020 are not competing designs. They cover two different operator needs:

- CLI:
  - repeatable, named workflows
- JS runtime:
  - custom logic, ad hoc assertions, snippet-based automation

Both can coexist if they share the same target registry and subsystem concepts.

## Runtime Architecture

### Context creation

Every snippet should execute within a runtime context:

```ts
type RuntimeContext = {
  target: ReleaseTarget;
  env: Record<string, string>;
  exec: ExecAdapter;
  logger: Logger;
  cache: Cache;
};
```

Context boot sequence:

```text
resolve target
  -> resolve credentials
  -> resolve repo paths
  -> resolve cluster auth strategy
  -> construct subsystem clients
  -> run snippet
```

### Waiter design

All waiters should support:

- timeout,
- interval,
- progress reporting,
- cancellation.

Pseudocode:

```ts
async function waitUntil<T>(
  label: string,
  check: () => Promise<{ done: boolean; value?: T; detail?: string }>,
  opts: { timeoutMs: number; intervalMs: number }
): Promise<T> {
  const started = Date.now();
  while (Date.now() - started < opts.timeoutMs) {
    const result = await check();
    if (result.done) return result.value!;
    await sleep(opts.intervalMs);
  }
  throw new Error(`${label} timed out`);
}
```

Later phases can replace some interval waits with event-driven implementations, but the public API should stay the same.

### Credential resolution

The runtime should never store credentials directly in target files.

Instead:

- GitHub auth should come from environment or runtime config,
- public basic-auth verification credentials should come from env vars,
- kubeconfig resolution should be delegated to the selected cluster auth strategy.

### Cluster auth strategy

Cluster auth must be explicit because this platform has both:

- a wrong-by-default local kubeconfig failure mode,
- and a documented Tailscale recovery path.

Phase 1 should support:

- `tailscale`
- `existing-kubeconfig`

For `tailscale`, the runtime can simply wrap:

- `scripts/get-kubeconfig-tailscale.sh`

and then cache the resolved kubeconfig path in the runtime context.

## Example Snippets

### Example 1: Full release flow

```js
const target = await releases.getTarget("pretext-trace");
const head = await source.git(target).pushCurrentBranch();
const run = await source.github(target).waitForWorkflowRun({
  workflow: "publish-trace-server-image.yaml",
  sha: head.sha,
});

await registry.ghcr().waitForImage(run.imageRef);
const pr = await gitops.repo(target).waitForOrCreateImageBumpPr({
  image: run.imageRef,
});
await gitops.repo(target).mergePr(pr.number);

await cluster.auth("tailscale").ensure();
await argo.app(target).refresh();
await argo.app(target).waitForRevision(pr.mergeCommitSha);
await cluster.deployment(target).waitForRollout();

await verify.http(target).expectBasicAuthChallenge();
await verify.http(target).expectHealthOk();
await verify.page(target).expectText("non-loopback host");
```

### Example 2: Merge only if the PR is a one-line image bump

```js
const target = await releases.getTarget("pretext-trace");
const pr = await gitops.repo(target).waitForOpenPr();
const diff = await gitops.repo(target).diffPr(pr.number);

if (diff.files.length !== 1 || diff.files[0].changedLines !== 1) {
  throw new Error("PR is not a simple image bump");
}

await gitops.repo(target).mergePr(pr.number);
```

### Example 3: Verify desired vs actual image after merge

```js
const target = await releases.getTarget("pretext-trace");
const desired = await gitops.repo(target).desiredImage();
await cluster.auth("tailscale").ensure();
const actual = await cluster.deployment(target).getImage();

if (desired !== actual) {
  throw new Error(`deployment drift: desired=${desired} actual=${actual}`);
}
```

## API References And File References

### GitHub Actions

Current operator surface:

- `gh run list`
- `gh run view`

Likely future API calls:

- `GET /repos/{owner}/{repo}/actions/runs`
- `GET /repos/{owner}/{repo}/actions/runs/{run_id}`

Fields needed:

- run status
- conclusion
- head SHA
- workflow name
- run URL

### GitHub Pull Requests

Current operator surface:

- `gh pr list`
- `gh pr view`
- `gh pr diff`
- `gh pr merge`

Fields needed:

- PR number
- changed files
- merge state
- merge commit SHA

### Kubernetes / Argo

Current operator surface:

- `kubectl -n argocd get application ...`
- `kubectl -n <ns> get deployment ...`
- `kubectl rollout status ...`

Fields needed:

- Argo revision
- Argo health and sync state
- Deployment image
- updated and ready replicas
- rollout completion

### Public HTTP verification

Current operator surface:

- `curl` with and without auth
- `rg` on served HTML

The runtime should keep this simple in phase 1. It does not need a browser engine for the initial implementation.

## Alternatives Considered

### Alternative 1: CLI only

Rejected because:

- some tasks are too custom for a stable verb tree,
- a snippet runtime is better for conditional and ad hoc release logic.

### Alternative 2: Shell snippets instead of JS snippets

Rejected because:

- shell is awkward for structured state,
- shell encourages open-coded polling loops,
- and shell return values are less composable than JS objects.

### Alternative 3: Full native SDK from day one

Rejected for v1 because:

- it would duplicate too much already-working tooling,
- phase 1 can get value faster by wrapping stable tools first.

### Alternative 4: Put all release logic only in source repos

Rejected because:

- cluster auth, Argo state, ingress verification, and rollout topology still belong to the infra side.

## Implementation Plan

### Phase 1: Target registry and subprocess-backed SDK

Add:

```text
packages/hk3s-runtime/
releases/targets/
```

Implement:

- target loading,
- subprocess adapter,
- `source`, `registry`, `gitops`, `cluster`, and `verify`,
- `release.status()`.

### Phase 2: Waiters and snippet runner

Implement:

- waiter helpers,
- `release.wait(...)`,
- a small file-based or REPL-based snippet runner.

For example:

```bash
node scripts/run-release-snippet.mjs ./snippets/release-pretext-trace.mjs
```

### Phase 3: Composed release helpers

Implement:

- `release.run(...)`
- `release.verify(...)`
- `release.rollback(...)`

Keep these as library calls even if a runner wraps them.

### Phase 4: Native client upgrades

Replace the highest-value polling loops first:

- GitHub Actions status
- PR status
- Kubernetes rollout state

Do not replace shell-outs that remain simple and stable without a clear benefit.

### Phase 5: Broaden target coverage

Validate against:

- `pretext-trace`
- `mysql-ide`
- one app with more complex auth or image-pull behavior

## Validation Strategy

### Local validation

```js
const target = await releases.getTarget("pretext-trace");
console.log(await release.status(target));
```

### Dry-run integration validation

Validate that the runtime can:

- resolve targets,
- read workflow state,
- confirm image existence,
- inspect PR state,
- ensure cluster auth,
- inspect Deployment image and rollout state,
- perform auth and health verification.

### Real-world validation

The strongest proof remains a small real release. This design is explicitly derived from the `pretext-trace` rollout and should eventually be proven against another similar release.

## Open Questions

1. Should the runtime live in this repo or in a dedicated automation-tools repo?
2. Should snippets run only locally, or also in a hosted runtime later?
3. Should the runtime eventually power some CLI verbs, or stay purely library-first?
4. How much credential resolution should be automatic versus explicit?

## References

- `docs/source-app-deployment-infrastructure-playbook.md`
- `docs/app-packaging-and-gitops-pr-standard.md`
- `docs/tailscale-k3s-admin-access-playbook.md`
- `scripts/get-kubeconfig-tailscale.sh`
- `gitops/applications/pretext-trace.yaml`
- `gitops/kustomize/pretext-trace/deployment.yaml`
- `ttmp/2026/03/30/HK3S-0019--design-a-release-orchestration-cli-for-source-to-gitops-app-deployments/`

---
Title: Investigation diary for JavaScript release automation runtime design
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
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/source-app-deployment-infrastructure-playbook.md
      Note: Current deployment-system source of truth that the JS runtime will automate
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/30/HK3S-0019--design-a-release-orchestration-cli-for-source-to-gitops-app-deployments/design-doc/01-release-orchestration-cli-design-and-implementation-guide.md
      Note: Closely related CLI design used as a comparison point
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/get-kubeconfig-tailscale.sh
      Note: Current cluster auth helper that a JS runtime would likely wrap first
    - Path: /home/manuel/code/wesen/2026-03-30--pretext-wasm/.github/workflows/publish-trace-server-image.yaml
      Note: Source-repo workflow used in the motivating release scenario
ExternalSources: []
Summary: "Chronological diary for deriving a JS-API-based release runtime from the real pretext-trace source-to-GitOps rollout."
LastUpdated: 2026-03-30T11:18:00-04:00
WhatFor: "Use this to review the concrete evidence and command sequences that motivated the JavaScript runtime design."
WhenToUse: "Read this when implementing the runtime or when checking why a JS-first approach is useful in addition to a CLI."
---

# Investigation diary for JavaScript release automation runtime design

## Goal

Capture the reasoning behind a JavaScript automation runtime for release operations, using the real `pretext-trace` rollout and the CLI ticket as the evidence set.

## Context

The first ticket, HK3S-0019, answered the question “what would the best CLI look like?” This follow-on ticket answers a different question:

- what would the same system look like if we wanted short programmable snippets instead of fixed commands?

That distinction matters because some tasks are too specific for a permanent verb, but still frequent enough to deserve stable subsystem APIs.

## Step 1: Reuse the exact same motivating scenario

I deliberately reused the `pretext-trace` release as the primary evidence source. The system boundaries and release pain are already real there, so inventing a new scenario would only weaken the design.

### What I did

- Reused the same command bursts from the source-to-GitOps rollout.
- Compared which parts felt like “one command should do this” and which parts felt like “I need a little logic here.”

Commands that still mattered:

```bash
gh run list -R wesen/2026-03-30--pretext-wasm --workflow publish-trace-server-image.yaml --limit 5
gh run view 23750576387 -R wesen/2026-03-30--pretext-wasm --json status,conclusion,jobs,url
docker manifest inspect ghcr.io/wesen/2026-03-30--pretext-wasm-trace-server:sha-36515c2
gh pr list -R wesen/2026-03-27--hetzner-k3s --limit 20
gh pr merge 10 -R wesen/2026-03-27--hetzner-k3s --merge --delete-branch
./scripts/get-kubeconfig-tailscale.sh
kubectl -n pretext-trace rollout status deployment/pretext-trace --timeout=120s
curl -u 'friend:trace-friends-2026' https://pretext-trace.yolo.scapegoat.dev/health
```

### What I learned

- The same release path that motivates the CLI also motivates the runtime.
- The difference is not in the systems involved. The difference is in how much custom logic the operator wants.

## Step 2: Identify the specific places where snippets are better than verbs

The CLI is strongest when the workflow is stable enough to deserve a named command. The runtime is strongest where the operator wants to add a little custom behavior.

Examples that pushed this design:

- merge only if the PR diff is exactly one line,
- wait for rollout, then assert the served HTML contains a marker string,
- compare desired image, actual Deployment image, and served page state in one short program,
- branch based on whether public verification already succeeded.

### What worked

- These examples all map naturally to small JS programs.

### What didn’t work

- They would be awkward as shell loops.
- They would also be awkward as a huge CLI surface with too many subcommands.

### What I learned

- The runtime should optimize for programmable composition, not just operator ergonomics.

## Step 3: Decide that the runtime should be a library first

Once the problem was framed correctly, the right implementation stance became obvious:

- build a library first,
- then add a snippet runner or REPL integration,
- instead of starting with a pseudo-CLI written in JS.

### Why

- A library gives stable object models and structured return values.
- A runner can always be added later.
- The value is in the APIs and waiters, not in a thin command wrapper.

### What I learned

- The key design unit is a subsystem client, not a shell command.

## Step 4: Derive the subsystem APIs from the current platform boundaries

The subsystem list was not invented from scratch. It came directly from the real release path:

- `releases`
- `source`
- `registry`
- `gitops`
- `argo`
- `cluster`
- `verify`
- `release`

That mapping was important because it guarantees the runtime still matches the real control planes rather than flattening them into one opaque abstraction.

### What worked

- The existing docs and rollout commands already implied a clean object model.

### What didn’t work

- That model currently exists only in docs and operator memory, not in code.

## Quick Reference

### Proposed import surface

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

### Proposed snippet style

```js
const target = await releases.getTarget("pretext-trace");
const run = await source.github(target).waitForWorkflowRun({
  workflow: "publish-trace-server-image.yaml",
  sha: target.source.headSha,
});
await registry.ghcr().waitForImage(run.imageRef);
const pr = await gitops.repo(target).waitForOrCreateImageBumpPr({ image: run.imageRef });
await gitops.repo(target).mergePr(pr.number);
await cluster.auth("tailscale").ensure();
await argo.app(target).waitForRevision(pr.mergeCommitSha);
await cluster.deployment(target).waitForRollout();
await verify.http(target).expectHealthOk();
```

### Proposed target metadata

```yaml
name: pretext-trace
sourceRepo:
  githubRepo: wesen/2026-03-30--pretext-wasm
  workflow: publish-trace-server-image.yaml
gitopsRepo:
  githubRepo: wesen/2026-03-27--hetzner-k3s
  manifestPath: gitops/kustomize/pretext-trace/deployment.yaml
cluster:
  namespace: pretext-trace
  deployment: pretext-trace
verify:
  healthUrl: https://pretext-trace.yolo.scapegoat.dev/health
```

## Usage Examples

### Example 1: Compare desired and actual image

```js
const target = await releases.getTarget("pretext-trace");
const desired = await gitops.repo(target).desiredImage();
await cluster.auth("tailscale").ensure();
const actual = await cluster.deployment(target).getImage();

if (desired !== actual) {
  throw new Error(`deployment drift: desired=${desired} actual=${actual}`);
}
```

### Example 2: Auth verification only

```js
const target = await releases.getTarget("pretext-trace");
await verify.http(target).expectBasicAuthChallenge();
await verify.http(target).expectHealthOk();
```

### Example 3: Wait for public success

```js
const target = await releases.getTarget("pretext-trace");
await release.wait(target, "public-ok");
```

## What warrants a second pair of eyes

- Whether the runtime should be kept in this repo or extracted later.
- Whether snippets should run through a file runner, REPL integration, or both.
- Whether the runtime should eventually back some CLI commands or stay library-only.

## Code review instructions

Read this diary together with:

- the CLI design ticket HK3S-0019,
- `docs/source-app-deployment-infrastructure-playbook.md`,
- `docs/app-packaging-and-gitops-pr-standard.md`,
- `scripts/get-kubeconfig-tailscale.sh`,
- and the `pretext-trace` workflow and Deployment files.

The runtime design is correct only if its APIs map directly back to those real system boundaries and reduce manual polling without erasing the architecture.

## Related

- `ttmp/2026/03/30/HK3S-0019--design-a-release-orchestration-cli-for-source-to-gitops-app-deployments/`
- `docs/source-app-deployment-infrastructure-playbook.md`
- `docs/app-packaging-and-gitops-pr-standard.md`
- `docs/tailscale-k3s-admin-access-playbook.md`

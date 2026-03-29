---
Title: Investigation Diary
Ticket: HK3S-0016
Status: active
Topics:
    - ci-cd
    - github
    - ghcr
    - argocd
    - gitops
    - kubernetes
    - deployment
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - /home/manuel/code/wesen/2026-03-29--serve-claude-experiments/cmd/serve-artifacts/main.go:app entrypoint
    - /home/manuel/code/wesen/2026-03-29--serve-claude-experiments/pkg/server/precompiled.go:go:generate and go:embed for JSX bundles
    - /home/manuel/code/wesen/2026-03-29--serve-claude-experiments/go.mod:Go module definition
    - /home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml:reference CI workflow
    - /home/manuel/code/wesen/2026-03-27--mysql-ide/scripts/open_gitops_pr.py:reference GitOps PR updater
    - /home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/source-app-deployment-infrastructure-playbook.md:full deployment model
    - /home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/public-repo-ghcr-argocd-deployment-playbook.md:public repo GHCR pattern
    - /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/pretext/deployment.yaml:reference stateless deployment
ExternalSources: []
Summary: "Chronological investigation diary for deploying serve-claude-experiments as artifacts.yolo.scapegoat.dev"
LastUpdated: 2026-03-29T11:47:20.838395269-04:00
WhatFor: ""
WhenToUse: ""
---

# Diary

## Goal

Document the investigation, planning, and implementation of deploying the `serve-claude-experiments` Go application as `artifacts.yolo.scapegoat.dev` with the full GitHub Actions -> GHCR -> GitOps PR -> Argo CD pipeline.

## Step 1: Architecture Research and Evidence Gathering

The first step was understanding both the application and the deployment platform to create an evidence-based implementation plan.

The application is a Go server built with Glazed that serves Claude.ai artifacts. The deployment platform uses Argo CD watching a GitOps repo with Kustomize packages. The key question was: what build-time and runtime requirements does this app have that affect the Dockerfile and deployment shape?

### Prompt Context

**User prompt (verbatim):** "Create a new ticket with docmgr to deploy my claude artifacts page as artifacts.yolo.scapegoat.dev with github PR pipeline. Read the docs here and create a detailed implementation guide and upload it to remarkable when done. The repo is /home/manuel/code/wesen/2026-03-29--serve-claude-experiments and is public on github. Keep a diary as you work."

**Assistant interpretation:** Create a comprehensive implementation guide for deploying the serve-claude-experiments app to the K3s cluster, following the established patterns documented in the hetzner-k3s repo.

**Inferred user intent:** Get a complete, actionable deployment plan that follows the existing platform conventions so the deployment can be executed cleanly.

### What I did

1. Explored the serve-claude-experiments repo structure:
   - `cmd/serve-artifacts/main.go` — Glazed/Cobra app with `serve` and `list` commands
   - `pkg/server/precompiled.go` — `go:generate` runs `cmd/precompile-jsx-bundle` to transform JSX to JS via esbuild, then `go:embed` packages the results
   - `pkg/server/server.go` — embeds `templates/` directory
   - `imports/` — ~30 HTML/JSX artifact files with companion manifest JSONs
   - Go 1.25.7, depends on `esbuild v0.27.4` (Go dependency, not Node.js)

2. Read all deployment playbooks in the k3s repo:
   - `docs/source-app-deployment-infrastructure-playbook.md` — the canonical deployment model
   - `docs/public-repo-ghcr-argocd-deployment-playbook.md` — public repo GHCR pattern (mysql-ide reference)
   - `docs/app-packaging-and-gitops-pr-standard.md` — packaging standard with Category 1-5 taxonomy
   - `docs/argocd-app-setup.md` — Argo CD Application setup guide
   - `docs/coinvault-k3s-deployment-playbook.md` — complex deployment with Vault/VSO (for contrast)

3. Examined reference implementations:
   - `mysql-ide` — full CI/CD pipeline (Dockerfile, publish-image.yaml, gitops-targets.json, open_gitops_pr.py)
   - `pretext` — Category 1 stateless app GitOps package (namespace, deployment, service, ingress, kustomization)
   - `coinvault` — Category 2 app with Vault/VSO (for understanding what we DON'T need)

4. Verified tests pass cleanly in the app repo: `go test ./...` — all 3 test packages pass

### Why

Need evidence-based understanding of:
- Build requirements (the `go generate` step is non-obvious — uses esbuild via Go, not Node.js)
- Runtime requirements (binary + imports directory)
- Platform patterns (which playbook category, what manifests are needed)
- Credential requirements (GITOPS_PR_TOKEN for cross-repo PRs)

### What worked

- The platform playbooks are excellent — they document not just the "how" but the "why" and common failure modes
- The mysql-ide reference implementation provides a complete template for the CI pipeline
- The pretext package provides a clean minimal template for the GitOps manifests

### What didn't work

- N/A — this was a research step

### What I learned

1. **Category 1 deployment:** serve-claude-experiments is a public stateless app with no secrets — the simplest deployment category. No Vault/VSO, no ServiceAccount, no PVC needed.

2. **Build-time JSX precompilation:** The `go:generate` step uses esbuild as a Go dependency (not Node.js). This means the Dockerfile multi-stage build can run `go generate` in the standard `golang:1.25-bookworm` image without adding Node.js.

3. **Runtime artifact directory:** The binary embeds precompiled bundles but still needs the `imports/` directory at runtime for discovery and serving. The embedded bundles are an optimization for known artifacts — new/changed JSX files fall back to Babel in the browser.

4. **GHCR package visibility:** Public repos can still produce private GHCR packages by default. Must explicitly set visibility to public after first publish.

5. **enableServiceLinks: false:** The CoinVault playbook documents a real failure where Kubernetes service links injected `COINVAULT_PORT=tcp://...` that collided with app config. The pretext deployment does NOT set this, but mysql-ide does. Following mysql-ide's pattern.

6. **No health endpoint:** The app doesn't have a `/healthz` route. Using `/` (the index page) for probes is the pragmatic choice for now.

### What was tricky to build

Nothing tricky in this step — it was pure research. The main complexity was understanding the `go:generate` -> `go:embed` chain and confirming that esbuild works without Node.js in the build container.

### What warrants a second pair of eyes

- The Dockerfile `go generate` step: does it need any special environment or flags? The precompile tool reads from `../../imports` relative to `pkg/server/`, which means the WORKDIR and COPY layout in the Dockerfile must preserve that path relationship.

### What should be done in the future

- Add a `/healthz` endpoint to the server for cleaner probe behavior
- Consider adding a `--version` flag that embeds the git SHA at build time

### Code review instructions

- Start with the implementation guide at `ttmp/2026/03/29/HK3S-0016--deploy-serve-claude-experiments-as-artifacts-yolo-scapegoat-dev/design/01-implementation-guide-deploy-serve-claude-experiments.md`
- Compare the proposed Dockerfile against `pkg/server/precompiled.go` lines 1-20 to verify the `go generate` path relationship
- Compare the proposed workflow against `/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml`
- Compare the proposed GitOps manifests against `gitops/kustomize/pretext/` for structural alignment

### Technical details

Key file relationships for the build:
```
cmd/precompile-jsx-bundle/main.go  -- the go:generate tool
  reads: imports/*.jsx
  writes: pkg/server/precompiled/*.js + manifest.json

pkg/server/precompiled.go
  //go:generate go run ../../cmd/precompile-jsx-bundle --dir ../../imports --out ./precompiled
  //go:embed precompiled
  var precompiledFS embed.FS

pkg/server/server.go
  //go:embed templates
  var templateFS embed.FS
```

Runtime: binary serves from `--dir <path>` (default `.`) and uses embedded precompiled bundles as optimization layer.

## Step 2: Implementation — App Repo Packaging and GitOps Manifests

Implemented all the packaging files in the app repo and all GitOps manifests in the infra repo, then pushed both to trigger the CI pipeline and Argo CD sync.

The main surprise was that the initial Dockerfile used `CGO_ENABLED=0`, but the app depends on `go-sqlite3` which requires cgo. The container crashed immediately with a clear error. Switching to `CGO_ENABLED=1` fixed it — the distroless base image already includes glibc.

### Prompt Context

**User prompt (verbatim):** (see Step 1)

**Assistant interpretation:** Execute the implementation plan from Step 1 — create all files, test locally, commit and push.

**Inferred user intent:** Get the full CI/CD pipeline and GitOps deployment wired up and running.

**Commit (code):** 0f000f7 — "feat: add CI/CD pipeline for GHCR publishing and GitOps PR automation" (app repo)
**Commit (code):** 700de99 — "feat: scaffold artifacts deployment for serve-claude-experiments" (GitOps repo)

### What I did

1. Created `Dockerfile` in serve-claude-experiments:
   - Multi-stage build: `golang:1.25-bookworm` -> `gcr.io/distroless/base-debian12:nonroot`
   - `go generate ./pkg/server` runs JSX precompilation in the build stage
   - Copies `imports/` directory into runtime image for artifact serving
   - Default CMD: `serve --dir /app/imports --port 8080`

2. Tested Docker build locally:
   - Build succeeded: `go generate` produced 15 precompiled JSX artifacts
   - First run failed: `go-sqlite3 requires cgo to work` (binary compiled with `CGO_ENABLED=0`)
   - Fixed: changed to `CGO_ENABLED=1`
   - Second run succeeded: container serves artifact index on port 8080, HTTP 200

3. Copied `scripts/open_gitops_pr.py` from mysql-ide (generic script, no changes needed)

4. Created `deploy/gitops-targets.json` targeting `gitops/kustomize/artifacts/deployment.yaml`

5. Created `.github/workflows/publish-image.yaml` (identical structure to mysql-ide)

6. Created GitOps manifests in hetzner-k3s:
   - `gitops/applications/artifacts.yaml` — Argo CD Application
   - `gitops/kustomize/artifacts/` — namespace, deployment, service, ingress, kustomization
   - Initial image set to `sha-0f000f7` (the commit that added the Dockerfile)

7. Validated kustomize render: `kubectl kustomize gitops/kustomize/artifacts` — clean output

8. Committed and pushed both repos

### Why

Follow the established platform pattern: app repo publishes to GHCR via CI, GitOps repo declares desired state, Argo CD reconciles.

### What worked

- Docker build with `go generate` works cleanly in the `golang:1.25-bookworm` image — esbuild is a Go dependency, no Node.js needed
- The mysql-ide CI workflow and PR updater script are completely generic and reusable
- The pretext GitOps package provides a clean minimal template for Category 1 apps
- Kustomize render validates correctly

### What didn't work

- **CGO_ENABLED=0 crashed at runtime:** The app uses `go-sqlite3` (transitive dependency via Glazed) which requires cgo. The container started but immediately crashed with `Binary was compiled with 'CGO_ENABLED=0', go-sqlite3 requires cgo to work`. Fixed by switching to `CGO_ENABLED=1`. The `distroless/base-debian12` image already includes glibc, so the dynamically linked binary works fine.

### What I learned

1. **go-sqlite3 requires cgo:** Even if the app doesn't directly use SQLite, Glazed pulls in go-sqlite3 as a dependency. Always check transitive dependencies before assuming CGO_ENABLED=0 is safe.

2. **distroless base includes glibc:** `gcr.io/distroless/base-debian12:nonroot` has glibc, so CGO-enabled Go binaries work. The `static` variant does not.

3. **Generic PR updater script:** The `open_gitops_pr.py` script is completely app-agnostic. It reads target metadata from JSON and patches the image field. Can be copied as-is.

### What was tricky to build

The CGO issue was the only unexpected problem. The error message was clear and the fix was straightforward (change `CGO_ENABLED=0` to `CGO_ENABLED=1`). The real lesson is to always test the container before pushing to CI.

### What warrants a second pair of eyes

- The GHCR package visibility: public repos can still produce private packages. Need to check after first publish.
- The initial deployment image `sha-0f000f7` must match what GHCR actually publishes. The metadata action uses a 7-char SHA prefix, and the commit hash is `0f000f7`.

### What should be done in the future

- Add `GITOPS_PR_TOKEN` to the app repo settings for automated GitOps PRs
- Set GHCR package visibility to public after first publish

### Code review instructions

- App repo: `git log --oneline -1` shows `0f000f7`
  - Review `Dockerfile` for CGO_ENABLED=1 and the go generate step
  - Review `.github/workflows/publish-image.yaml` for correct metadata and push conditions
  - Review `deploy/gitops-targets.json` for correct manifest path and container name
- GitOps repo: `git log --oneline -1` shows `700de99`
  - Review `gitops/applications/artifacts.yaml` for correct source path
  - Review `gitops/kustomize/artifacts/deployment.yaml` for correct image, probes, and resource limits
  - Review `gitops/kustomize/artifacts/ingress.yaml` for correct hostname and TLS

### Technical details

Docker build output (key step):
```
#15 [build 8/9] RUN go generate ./pkg/server
#15 9.809 generated 15 precompiled JSX artifacts in ./precompiled
#15 DONE 10.0s
```

CGO crash error (before fix):
```
{"level":"fatal","error":"failed to create tables: failed to create sections table: Binary was compiled with 'CGO_ENABLED=0', go-sqlite3 requires cgo to work. This is a stub","time":"2026-03-29T16:03:22Z","message":"Failed to create in-memory store"}
```

Container test (after fix):
```
$ docker run --rm -d -p 8081:8080 serve-artifacts:test
$ curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/
200
```

## Step 3: CI Pipeline Verification and GITOPS_PR_TOKEN Lesson

The CI pipeline ran successfully — Docker image was built and pushed to GHCR in 4m27s. Argo CD synced the deployment and the pod came up healthy. However, the GitOps PR job silently skipped because `GITOPS_PR_TOKEN` was not configured yet.

This was a real deployment bug: the image was published to GHCR, the pod was running with the initial image tag from the GitOps commit, but no automated PR was opened to update the image. The workflow's silent `exit 0` on missing token masked the problem.

### Prompt Context

**User prompt (verbatim):** "I set up the GITOPS_PR_TOKEN secret, which was keeping us from opening the gitops PR. We should make sure that we fail when the gitops PR doesn't work [...] Make sure to update the documentation where necessary so we don't do the same mistake next time"

**Assistant interpretation:** Change the workflow to fail loudly when GITOPS_PR_TOKEN is missing, and update the implementation guide to emphasize configuring the token before the first push.

**Inferred user intent:** Prevent silent failures in the deployment pipeline where the image publishes but no deployment update is proposed.

**Commit (code):** c2f7237 — "fix: fail loudly when GITOPS_PR_TOKEN is missing instead of silently skipping" (app repo)

### What I did

1. Changed `.github/workflows/publish-image.yaml`:
   - `exit 0` -> `exit 1` when GH_TOKEN is empty
   - Added `::error::` annotation for GitHub Actions UI visibility

2. Updated the implementation guide:
   - Changed the workflow code block to show the new `exit 1` behavior
   - Updated the description to explain the token is required, not optional
   - Moved GITOPS_PR_TOKEN setup to Phase 1 (before the first push), not Phase 3 (after)
   - Updated CI validation section to note the workflow fails if token is missing

### Why

The mysql-ide workflow pattern uses silent skip (`exit 0`) for the GITOPS_PR_TOKEN check. This was inherited from the docs which recommended it as a safety measure so PR builds don't fail. But for a main-branch push where the intent is always to open a GitOps PR, a silent skip is worse than a failure — it creates a gap in the deployment pipeline that's hard to notice.

### What worked

- The fix is minimal: two lines changed in the workflow
- The documentation updates make the ordering explicit: configure the token first, then push

### What didn't work

- The original silent-skip pattern from the platform playbooks was copied without questioning whether it fit this use case. For the `gitops-pr` job (which only runs on main pushes, not PRs), a missing token always means something is wrong.

### What I learned

1. **Silent skips are dangerous for required steps.** The `exit 0` pattern makes sense for optional features, but the GitOps PR is not optional — it's the whole point of the CI pipeline. A failure is more helpful than a silent skip.

2. **Configure secrets before the first push.** The phased implementation plan originally had GITOPS_PR_TOKEN in Phase 3 (after the first push). It should be in Phase 1 (before the first push) because the workflow now fails without it.

### What was tricky to build

Nothing tricky — the fix was straightforward. The tricky part was noticing the problem in the first place. The CI run showed as "successful" because the skip step exited 0.

### What warrants a second pair of eyes

- Should the mysql-ide workflow also be updated to fail loudly? The same pattern exists there but the token is already configured, so the bug never manifests.

### What should be done in the future

- Consider updating the platform playbook (`source-app-deployment-infrastructure-playbook.md`) to recommend `exit 1` instead of `exit 0` for the token check, or at least document the tradeoff explicitly.

### Code review instructions

- App repo: `git diff 0f000f7..c2f7237` shows the two-line change
- GitOps repo: review the updated implementation guide sections on GITOPS_PR_TOKEN

### Technical details

The original CI output that masked the problem:
```
GITOPS_PR_TOKEN is not configured; skipping GitOps PR creation.
```

This appeared as a green checkmark in GitHub Actions. The new behavior:
```
::error::GITOPS_PR_TOKEN is not configured. Add it as a repository secret.
```
This will appear as a red X with a clear error annotation.

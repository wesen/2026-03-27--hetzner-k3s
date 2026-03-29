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

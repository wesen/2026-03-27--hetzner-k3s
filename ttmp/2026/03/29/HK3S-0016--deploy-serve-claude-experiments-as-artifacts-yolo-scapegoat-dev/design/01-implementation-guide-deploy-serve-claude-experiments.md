---
Title: 'Implementation Guide: Deploy serve-claude-experiments'
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
DocType: design
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../2026-03-27--mysql-ide/.github/workflows/publish-image.yaml:reference CI workflow
    - Path: ../../../../../../../2026-03-27--mysql-ide/deploy/gitops-targets.json:reference deployment targets
    - Path: ../../../../../../../2026-03-27--mysql-ide/scripts/open_gitops_pr.py:reference GitOps PR updater
    - Path: ../../../../../../../2026-03-29--serve-claude-experiments/cmd/serve-artifacts/main.go
      Note: app entrypoint
    - Path: ../../../../../../../2026-03-29--serve-claude-experiments/cmd/serve-artifacts/main.go:app entrypoint
    - Path: ../../../../../../../2026-03-29--serve-claude-experiments/pkg/server/precompiled.go
      Note: go:generate and go:embed for JSX bundles
    - Path: ../../../../../../../2026-03-29--serve-claude-experiments/pkg/server/precompiled.go:go:generate and go:embed for JSX bundles
    - Path: ../../../../../../../2026-03-29--serve-claude-experiments/pkg/server/server.go:HTTP server with embedded templates
    - Path: docs/source-app-deployment-infrastructure-playbook.md
      Note: canonical deployment model
    - Path: gitops/applications/pretext.yaml:reference Argo CD Application for stateless app
    - Path: gitops/kustomize/pretext/deployment.yaml:reference stateless deployment
ExternalSources: []
Summary: Full implementation guide for deploying serve-claude-experiments as artifacts.yolo.scapegoat.dev with GitHub Actions CI/CD pipeline, GHCR image publishing, and Argo CD GitOps deployment.
LastUpdated: 2026-03-29T11:47:20.84771891-04:00
WhatFor: ""
WhenToUse: ""
---




# Implementation Guide: Deploy serve-claude-experiments as artifacts.yolo.scapegoat.dev

## Executive Summary

This guide covers deploying the `serve-claude-experiments` Go application as a public web service at `artifacts.yolo.scapegoat.dev`. The app serves Claude.ai artifacts (HTML and JSX files) from a local directory, with precompiled JSX bundles embedded at build time.

The deployment follows the established platform pattern:

1. Application repo publishes immutable GHCR images via GitHub Actions
2. CI opens GitOps PRs against the `hetzner-k3s` infra repo
3. Argo CD reconciles the Kubernetes manifests into the cluster

This is a **Category 1: Public stateless app** — no secrets, no database, no Vault/VSO wiring. The deployment shape is similar to `pretext` but with the full CI/CD pipeline like `mysql-ide`.

## Problem Statement and Scope

**Goal:** Make the Claude artifacts gallery available at `https://artifacts.yolo.scapegoat.dev` with automated deployments on push to `main`.

**Source repo:** `wesen/2026-03-29--serve-claude-experiments` (public on GitHub)

**What needs to be built:**

In the application repo:
- Dockerfile (multi-stage Go build with `go generate` for JSX precompilation)
- GitHub Actions workflow (`publish-image.yaml`)
- Deployment target metadata (`deploy/gitops-targets.json`)
- GitOps PR updater script (`scripts/open_gitops_pr.py`)

In the GitOps repo (`wesen/2026-03-27--hetzner-k3s`):
- Argo CD Application manifest
- Kustomize package (namespace, deployment, service, ingress)

**What is NOT in scope:**
- Authentication/OIDC (the app is public)
- Database or persistent storage (stateless)
- Vault/VSO secret wiring (no secrets)

## Current-State Architecture

### The Application

`serve-claude-experiments` is a Go application built with the Glazed command framework. It has two commands:

- `serve` — starts an HTTP server on port 8080 that serves artifacts from a directory
- `list` — outputs artifact metadata as structured data

Key build-time behavior:

- `go:generate go run ../../cmd/precompile-jsx-bundle --dir ../../imports --out ./precompiled` transforms JSX files into precompiled JavaScript bundles using esbuild (a Go dependency)
- `go:embed precompiled` and `go:embed templates` embed the precompiled bundles and HTML templates into the binary
- The `imports/` directory contains the actual artifact files (HTML, JSX, and manifest JSON)

Key runtime behavior:

- The `--dir` flag points to the artifact directory (defaults to `.`)
- HTML artifacts are served directly with a navigation bar injected
- JSX artifacts use a hybrid path: precompiled bundles for known artifacts, Babel fallback for new/changed ones
- The `--watch` flag enables SSE-based auto-reload

Important: the binary embeds the precompiled bundles at build time, but still needs the `imports/` directory at runtime to discover and serve artifact files. The embedded bundles are an optimization for known artifacts, not a replacement for the source files.

### Go Module and Dependencies

```
module github.com/go-go-golems/serve-artifacts
go 1.25.7
```

Key dependencies: `glazed v1.0.5`, `cobra v1.10.2`, `esbuild v0.27.4` (used by the precompile step), `fsnotify v1.9.0` (for `--watch`).

Tests pass cleanly:

```
ok   github.com/go-go-golems/serve-artifacts/pkg/artifacts
ok   github.com/go-go-golems/serve-artifacts/pkg/jsx
ok   github.com/go-go-golems/serve-artifacts/pkg/server
```

### Platform Infrastructure

The K3s cluster at `yolo.scapegoat.dev` already has:
- Argo CD watching `wesen/2026-03-27--hetzner-k3s` on `main`
- Traefik ingress controller
- cert-manager with `letsencrypt-prod` ClusterIssuer
- Working DNS wildcard for `*.yolo.scapegoat.dev`

## Gap Analysis

| Requirement | Current State | Gap |
|---|---|---|
| Container image | No Dockerfile exists | Must create multi-stage Dockerfile with go generate |
| CI/CD pipeline | No `.github/workflows/` directory | Must create publish-image workflow |
| GitOps PR automation | No `deploy/` or `scripts/` directory | Must add targets JSON and PR updater script |
| Kubernetes manifests | No GitOps package exists | Must create Kustomize package + Argo Application |
| DNS/TLS | Wildcard DNS already covers `*.yolo.scapegoat.dev` | None — cert-manager handles TLS |

## Proposed Solution

### Phase 1: Application Repository Packaging

#### 1.1 Dockerfile

Multi-stage build that handles the `go generate` step:

```dockerfile
FROM golang:1.25-bookworm AS build

WORKDIR /src

# Download dependencies first for layer caching
COPY go.mod go.sum ./
RUN go mod download

# Copy all source code
COPY cmd ./cmd
COPY pkg ./pkg
COPY imports ./imports

# Run go generate to precompile JSX bundles (uses esbuild via Go)
RUN go generate ./pkg/server

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/serve-artifacts ./cmd/serve-artifacts

FROM gcr.io/distroless/base-debian12:nonroot

WORKDIR /app

LABEL org.opencontainers.image.title="serve-claude-experiments" \
      org.opencontainers.image.description="Claude.ai artifact gallery server" \
      org.opencontainers.image.source="https://github.com/wesen/2026-03-29--serve-claude-experiments"

COPY --from=build /out/serve-artifacts /app/serve-artifacts
COPY --from=build /src/imports /app/imports

EXPOSE 8080

ENTRYPOINT ["/app/serve-artifacts"]
CMD ["serve", "--dir", "/app/imports", "--port", "8080"]
```

Key design decisions:
- `go generate` runs in the build stage because the precompile tool (`cmd/precompile-jsx-bundle`) uses esbuild which is a Go dependency — it works inside the Go build container without Node.js
- The `imports/` directory is copied into the runtime image because the server needs it to discover and serve artifact files at runtime
- `distroless/base-debian12:nonroot` for minimal attack surface
- Default CMD sets `--dir /app/imports --port 8080` so the container works without arguments

#### 1.2 GitHub Actions Workflow

File: `.github/workflows/publish-image.yaml`

```yaml
name: publish-image

on:
  pull_request:
  push:
    branches:
      - main
  workflow_dispatch:

permissions:
  contents: read
  packages: write
  pull-requests: write

concurrency:
  group: publish-image-${{ github.ref }}
  cancel-in-progress: true

jobs:
  docker:
    runs-on: ubuntu-latest

    steps:
      - name: Check out repository
        uses: actions/checkout@v5

      - name: Set up Go
        uses: actions/setup-go@v6
        with:
          go-version-file: go.mod
          cache: true

      - name: Run tests
        run: go test ./...

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4

      - name: Extract Docker metadata
        id: meta
        uses: docker/metadata-action@v6
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha,prefix=sha-
            type=raw,value=main,enable={{is_default_branch}}
            type=raw,value=latest,enable={{is_default_branch}}
          labels: |
            org.opencontainers.image.title=serve-claude-experiments
            org.opencontainers.image.description=Claude.ai artifact gallery server
            org.opencontainers.image.source=${{ github.server_url }}/${{ github.repository }}

      - name: Log in to GHCR
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push image
        uses: docker/build-push-action@v7
        with:
          context: .
          file: ./Dockerfile
          platforms: linux/amd64
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  gitops-pr:
    name: Open GitOps PR
    needs: docker
    if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest

    steps:
      - name: Check out repository
        uses: actions/checkout@v5

      - name: Set up Python
        uses: actions/setup-python@v6
        with:
          python-version: '3.x'

      - name: Open GitOps pull requests for published image
        env:
          GH_TOKEN: ${{ secrets.GITOPS_PR_TOKEN }}
          GITOPS_PR_GIT_AUTHOR_NAME: github-actions[bot]
          GITOPS_PR_GIT_AUTHOR_EMAIL: 41898282+github-actions[bot]@users.noreply.github.com
        run: |
          if [ -z "${GH_TOKEN}" ]; then
            echo "::error::GITOPS_PR_TOKEN is not configured. Add it as a repository secret."
            exit 1
          fi
          image_tag="sha-${GITHUB_SHA::7}"
          python3 scripts/open_gitops_pr.py \
            --config deploy/gitops-targets.json \
            --all-targets \
            --image "ghcr.io/${{ github.repository }}:${image_tag}" \
            --push \
            --open-pr
```

This is identical to the mysql-ide workflow with only the metadata labels changed. The `GITOPS_PR_TOKEN` secret **must** be configured before the first push to `main` — the workflow will fail with a clear error if it is missing. This is intentional: a silent skip caused a missed GitOps PR during the initial rollout of this app (the image was published but no deployment update was proposed).

#### 1.3 Deployment Targets

File: `deploy/gitops-targets.json`

```json
{
  "targets": [
    {
      "name": "artifacts-prod",
      "gitops_repo": "wesen/2026-03-27--hetzner-k3s",
      "gitops_branch": "main",
      "manifest_path": "gitops/kustomize/artifacts/deployment.yaml",
      "container_name": "serve-artifacts"
    }
  ]
}
```

#### 1.4 GitOps PR Updater Script

File: `scripts/open_gitops_pr.py`

Copy directly from `mysql-ide/scripts/open_gitops_pr.py`. The script is generic — it reads targets from JSON, patches the image field, and opens PRs. No app-specific logic inside.

### Phase 2: GitOps Repository Manifests

All files go under `gitops/kustomize/artifacts/` in the `hetzner-k3s` repo.

#### 2.1 Argo CD Application

File: `gitops/applications/artifacts.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: artifacts
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  destination:
    server: https://kubernetes.default.svc
    namespace: artifacts
  source:
    repoURL: https://github.com/wesen/2026-03-27--hetzner-k3s.git
    targetRevision: main
    path: gitops/kustomize/artifacts
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

#### 2.2 Kustomization

File: `gitops/kustomize/artifacts/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
  - ingress.yaml
```

#### 2.3 Namespace

File: `gitops/kustomize/artifacts/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: artifacts
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
```

#### 2.4 Deployment

File: `gitops/kustomize/artifacts/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: serve-artifacts
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  labels:
    app.kubernetes.io/name: serve-artifacts
    app.kubernetes.io/component: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: serve-artifacts
      app.kubernetes.io/component: web
  template:
    metadata:
      labels:
        app.kubernetes.io/name: serve-artifacts
        app.kubernetes.io/component: web
    spec:
      enableServiceLinks: false
      containers:
        - name: serve-artifacts
          image: ghcr.io/wesen/2026-03-29--serve-claude-experiments:sha-INITIAL
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
              name: http
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 3
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 10
            periodSeconds: 20
          resources:
            requests:
              cpu: 25m
              memory: 64Mi
            limits:
              memory: 256Mi
```

Key decisions:
- `enableServiceLinks: false` prevents the Kubernetes service-link environment variable collision that bit CoinVault
- No health endpoint exists yet — using `/` (the index page) for probes. If this proves noisy, a `/healthz` endpoint should be added to the app
- Memory limit 256Mi is generous for a static file server; can be reduced after observing real usage
- The initial image tag `sha-INITIAL` will be replaced by the first CI-created GitOps PR

#### 2.5 Service

File: `gitops/kustomize/artifacts/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: serve-artifacts
  annotations:
    argocd.argoproj.io/sync-wave: "1"
  labels:
    app.kubernetes.io/name: serve-artifacts
    app.kubernetes.io/component: web
spec:
  selector:
    app.kubernetes.io/name: serve-artifacts
    app.kubernetes.io/component: web
  ports:
    - port: 80
      targetPort: http
      protocol: TCP
      name: http
```

#### 2.6 Ingress

File: `gitops/kustomize/artifacts/ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: serve-artifacts
  annotations:
    argocd.argoproj.io/sync-wave: "2"
    cert-manager.io/cluster-issuer: letsencrypt-prod
  labels:
    app.kubernetes.io/name: serve-artifacts
    app.kubernetes.io/component: web
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - artifacts.yolo.scapegoat.dev
      secretName: serve-artifacts-tls
  rules:
    - host: artifacts.yolo.scapegoat.dev
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: serve-artifacts
                port:
                  number: 80
```

### Phase 3: Credential Setup

One credential is needed: `GITOPS_PR_TOKEN` in the `wesen/2026-03-29--serve-claude-experiments` repository settings.

This is a fine-grained GitHub personal access token with:
- **Repository access:** `wesen/2026-03-27--hetzner-k3s`
- **Permissions:**
  - Contents: Read and write
  - Pull requests: Read and write

The same token type used for mysql-ide can be reused or a new one can be created.

## Phased Implementation Plan

### Phase 1: App Repo Packaging (in `serve-claude-experiments`)

1. Create `Dockerfile`
2. Test Docker build locally:
   ```bash
   cd /home/manuel/code/wesen/2026-03-29--serve-claude-experiments
   docker build -t serve-artifacts:test .
   docker run --rm -p 8080:8080 serve-artifacts:test
   # Visit http://localhost:8080 to verify
   ```
3. Copy `scripts/open_gitops_pr.py` from mysql-ide
4. Create `deploy/gitops-targets.json`
5. Create `.github/workflows/publish-image.yaml`
6. **Configure `GITOPS_PR_TOKEN` secret in the repo settings BEFORE pushing to `main`.** The workflow will fail if this secret is missing — this is intentional to prevent silent skips where the image is published but no GitOps PR is opened.
7. Commit and push to `main`
8. Verify GitHub Actions builds, pushes to GHCR, and opens a GitOps PR
8. Verify GHCR package is publicly pullable:
   ```bash
   docker pull ghcr.io/wesen/2026-03-29--serve-claude-experiments:sha-<hash>
   ```

### Phase 2: GitOps Manifests (in `hetzner-k3s`)

1. Create `gitops/kustomize/artifacts/` with all manifests
2. Create `gitops/applications/artifacts.yaml`
3. Validate the kustomize render:
   ```bash
   kubectl kustomize gitops/kustomize/artifacts
   ```
4. Commit and push

### Phase 3: First Deployment

1. Apply the Argo CD Application manually: `kubectl apply -f gitops/applications/artifacts.yaml`
2. Force a refresh: `kubectl -n argocd annotate application artifacts argocd.argoproj.io/refresh=hard --overwrite`
3. The initial image will either succeed (if GHCR already has it) or fail with ImagePullBackOff
4. Merge the CI-created GitOps PR to update the image tag
5. Verify Argo syncs and the pod starts

### Phase 4: Validation

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml

# Check Argo status
kubectl -n argocd get application artifacts \
  -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{"\n"}'

# Check pod
kubectl -n artifacts get pods
kubectl -n artifacts logs deploy/serve-artifacts --tail=50

# Check ingress
curl -fsSL https://artifacts.yolo.scapegoat.dev/ | head -20
```

## Alternative: Bootstrap Without CI (Faster First Deploy)

If you want the app running before the CI pipeline is wired, you can do a one-time local build and import, similar to the pretext pattern:

```bash
cd /home/manuel/code/wesen/2026-03-29--serve-claude-experiments
docker build -t serve-artifacts:hk3s-0016 .
docker save serve-artifacts:hk3s-0016 | ssh root@91.98.46.169 'k3s ctr images import -'
```

Then set the deployment manifest to:
```yaml
image: serve-artifacts:hk3s-0016
imagePullPolicy: Never
```

This gets the app live immediately. Then switch to the GHCR-backed flow by changing to `imagePullPolicy: IfNotPresent` and the GHCR image reference once CI is working.

## Testing and Validation Strategy

### Local Validation

```bash
# Build and run locally
cd /home/manuel/code/wesen/2026-03-29--serve-claude-experiments
go test ./...
docker build -t serve-artifacts:test .
docker run --rm -p 8080:8080 serve-artifacts:test
# Browse http://localhost:8080 — verify artifact index loads
# Click an HTML artifact — verify it renders
# Click a JSX artifact — verify it renders (precompiled path)
```

### CI Validation

- GitHub Actions workflow completes successfully
- GHCR image is published with `sha-<hash>`, `main`, and `latest` tags
- GitOps PR is opened automatically (workflow fails if `GITOPS_PR_TOKEN` is missing)

### Cluster Validation

```bash
# Argo sync status
kubectl -n argocd get application artifacts -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{"\n"}'

# Pod running
kubectl -n artifacts get pods

# Index page
curl -fsSL https://artifacts.yolo.scapegoat.dev/

# Specific artifact
curl -fsSL https://artifacts.yolo.scapegoat.dev/artifacts/editor
```

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| `go generate` fails in Docker | Build breaks | The precompile tool uses esbuild as a Go dependency — no Node.js needed. Tested locally before CI. |
| GHCR package defaults to private | Cluster cannot pull | Manually set package visibility to public in GitHub after first publish |
| No `/healthz` endpoint | Probes hit index page, slightly noisy | Use `/` for now; add dedicated health endpoint if probe failures appear |
| Large image size due to `imports/` | Slower pulls | The imports are ~800KB total — negligible |
| Precompiled bundles stale if imports change | JSX artifacts fall back to Babel runtime | This is the designed behavior — the hybrid path handles it gracefully |

## Open Questions

1. **Health endpoint:** Should a `/healthz` route be added to the server? Currently using `/` for probes.
2. **Watch mode:** Should the container run with `--watch`? It is useful for development but adds fsnotify overhead in production. Recommendation: omit it for now.
3. **Resource limits:** The 256Mi memory limit is a guess. Should be tuned after observing actual usage.

## References

### Application Repository

- `/home/manuel/code/wesen/2026-03-29--serve-claude-experiments/cmd/serve-artifacts/main.go` — app entrypoint
- `/home/manuel/code/wesen/2026-03-29--serve-claude-experiments/pkg/server/server.go` — HTTP server
- `/home/manuel/code/wesen/2026-03-29--serve-claude-experiments/pkg/server/precompiled.go` — go:generate and go:embed
- `/home/manuel/code/wesen/2026-03-29--serve-claude-experiments/go.mod` — Go 1.25.7

### Platform Playbooks

- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/source-app-deployment-infrastructure-playbook.md` — full deployment infrastructure model
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/public-repo-ghcr-argocd-deployment-playbook.md` — public repo GHCR pattern
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/app-packaging-and-gitops-pr-standard.md` — packaging standard
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/argocd-app-setup.md` — Argo CD Application setup

### Reference Implementations

- `/home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml` — CI workflow template
- `/home/manuel/code/wesen/2026-03-27--mysql-ide/scripts/open_gitops_pr.py` — GitOps PR updater script
- `/home/manuel/code/wesen/2026-03-27--mysql-ide/deploy/gitops-targets.json` — deployment targets template
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/pretext/` — stateless app GitOps package
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml` — GHCR-backed deployment

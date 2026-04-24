# Changelog

## 2026-04-23

- Initial workspace created


## 2026-04-23

Created HK3S-0022 ticket workspace with design doc, tasks, and related files for packaging and deploying the goja-repl essay to K3s via ArgoCD, modeled after the codebase-browser deployment pattern.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/04/23/HK3S-0022--package-and-deploy-goja-repl-essay-to-k3s-via-argocd/design-doc/01-implementation-guide-deploy-goja-repl-essay-to-k3s.md — Design document


## 2026-04-23

Added Dockerfile, .dockerignore, GitHub Actions publish-image workflow, deploy/gitops-targets.json, and scripts/open_gitops_pr.py to go-go-goja app repo. Fixed missing @types/node in web/package.json for Vite config type-checking. Built and smoke-tested Docker image locally.

### Related Files

- /home/manuel/code/wesen/corporate-headquarters/go-go-goja/.github/workflows/publish-image.yaml — CI workflow to build
- /home/manuel/code/wesen/corporate-headquarters/go-go-goja/Dockerfile — Multi-stage Dockerfile for Node frontend + Go CGO backend + Debian runtime
- /home/manuel/code/wesen/corporate-headquarters/go-go-goja/deploy/gitops-targets.json — Deployment target metadata for GitOps PR automation
- /home/manuel/code/wesen/corporate-headquarters/go-go-goja/scripts/open_gitops_pr.py — Python script to open GitOps PRs for image bumps
- /home/manuel/code/wesen/corporate-headquarters/go-go-goja/web/package.json — Added @types/node devDependency for Vite config type-checking


## 2026-04-23

Added GitOps Kustomize package for goja-essay (namespace, PVC, deployment, service, ingress) and Argo CD Application manifest in hetzner-k3s repo. Domain: goja.yolo.scapegoat.dev.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/goja-essay.yaml — Argo CD Application manifest for goja-essay
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/goja-essay/deployment.yaml — Stateful deployment with SQLite PVC mount at /data
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/goja-essay/ingress.yaml — Ingress binding goja.yolo.scapegoat.dev
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/goja-essay/pvc.yaml — PersistentVolumeClaim for SQLite session storage


## 2026-04-23

Recovered stuck Argo CD sync by removing the deleting Application finalizer, clearing the stale namespace/PVC, recreating the Application, and syncing current Git. Verified goja.yolo.scapegoat.dev over HTTP and HTTPS, confirmed cert-manager issued goja-essay-tls, created a REPL essay session, deleted the pod, and confirmed the session survived restart via the SQLite PVC.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/goja-essay/deployment.yaml — Running deployment for goja essay image ghcr.io/go-go-golems/go-go-goja:sha-4398f5a
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/goja-essay/pvc.yaml — PVC sync-wave moved to 1 so local-path binding and Deployment creation happen in the same wave


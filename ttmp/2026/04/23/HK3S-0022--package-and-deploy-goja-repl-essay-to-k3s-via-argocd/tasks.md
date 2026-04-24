# Tasks

## Open

- [x] Add Dockerfile and .dockerignore to go-go-goja app repo
- [x] Add GitHub Actions workflow to build, test, and publish GHCR images
- [x] Add deploy/gitops-targets.json to go-go-goja app repo
- [x] Add GitOps PR helper script or reusable workflow wiring
- [x] Add GitOps kustomize package (namespace, pvc, deployment, service, ingress) in hetzner-k3s repo
- [x] Add Argo CD Application manifest for goja-essay in hetzner-k3s repo
- [ ] Bootstrap GITOPS_PR_TOKEN secret in go-go-goja repo
- [ ] Apply the Argo Application manually to the cluster
- [ ] Validate public rollout: essay page, session creation, SQLite persistence across pod restart

## Completed

- [x] Gather evidence from the app repo, the Hetzner K3s repo, and the codebase-browser deployment
- [x] Create the HK3S-0022 ticket workspace
- [x] Write the design document

## Notes

- The essay uses SQLite for session storage, so the Kubernetes package must include a PVC mounted at `/data`.
- The frontend builds with Vite to `web/dist/public` with base path `/static/essay/`.
- The backend finds static files via the `GOJA_REPL_ESSAY_WEB_DIST` environment variable.
- The goja-repl binary is CGO-enabled because of `mattn/go-sqlite3`, so the runtime image needs glibc.

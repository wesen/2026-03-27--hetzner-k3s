# Tasks

## TODO

- [x] Inspect the current Coolify runtime contract and source-repo deployment assumptions
- [x] Write the Draft Review K3s migration design and implementation guide
- [x] Write the migration playbook and initial diary
- [x] Package the Draft Review source repo for GHCR publishing and CI-created GitOps PRs
- [x] Add the Draft Review parallel Keycloak env in the Terraform repo
- [x] Add the Draft Review GitOps package in this repo
- [x] Add Vault runtime secret delivery for Draft Review
- [x] Add the Vault-backed private GHCR pull-secret path for Draft Review
- [x] Add a Postgres bootstrap job and create the `draft_review` database/user on shared Postgres
- [x] Add persistent media storage wiring for Draft Review uploads
- [x] Deploy the Draft Review Argo CD application
- [x] Validate health, OIDC login, database-backed behavior, and media persistence
- [x] Update the canonical deployment docs if the real migration exposes gaps in the current guidance
- [x] Restore the missing cluster-wide ACME `ClusterIssuer` as a dedicated GitOps-managed platform app
- [x] Inspect the hosted Draft Review database and author identity rows
- [x] Add a Terraform-managed `wesen` user to the Draft Review `k3s-parallel` Keycloak env
- [x] Apply Terraform and capture the new K3s Keycloak subject ID for `wesen`
- [x] Add ticket-local scripts to export the hosted Draft Review database and snapshot the cluster target database
- [x] Import hosted Draft Review data into the cluster `draft_review` database
- [x] Rewrite the imported `wesen@ruinwesen.com` author row to the K3s issuer and K3s Keycloak subject
- [x] Validate that logging in as `wesen` on K3s exposes the imported articles and ownership correctly

## Notes

- Source repo packaging now includes:
  - `.github/workflows/publish-image.yaml`
  - `deploy/gitops-targets.json`
  - `scripts/open_gitops_pr.py`
- Local validation completed:
  - `go test ./cmd/... ./pkg/... -count=1`
  - `docker build -t draft-review:local .`
  - `python3 scripts/open_gitops_pr.py --help`
- The `gitops-pr` workflow will still skip harmlessly until `GITOPS_PR_TOKEN` is configured in the Draft Review repo.
- Parallel Keycloak env created at:
  - `/home/manuel/code/wesen/terraform/keycloak/apps/draft-review/envs/k3s-parallel`
- Applied callback target:
  - `https://draft-review.yolo.scapegoat.dev/auth/callback`
- K3s package render validated with:
  - `KUBECONFIG=... kubectl kustomize gitops/kustomize/draft-review`
- Source image exists in GHCR as:
  - `ghcr.io/wesen/2026-03-24--draft-review:sha-125c36e`
- First live rollout exposed a platform gap:
  - the cluster had no `ClusterIssuer` resources at all
  - existing apps still had old TLS secrets, but new apps could only get Traefik's self-signed fallback cert
- Hosted Draft Review DB findings:
  - `users` table currently has 2 rows
  - the Manuel row is bound to:
    - issuer `https://auth.scapegoat.dev/realms/draft-review`
    - subject `ad1655b1-91ad-4b0b-8200-b33b8526244a`
  - the hosted schema predates `article_assets`, so target-schema-first import is safer than full schema restore
- K3s Keycloak `wesen` user created via Terraform:
  - subject `e0dfdba3-69f8-4b72-8033-d03c958af720`
  - password stored in 1Password item `draft-review yolo k3s wesen keycloak user 2026-03-29`
- Ticket-local migration scripts are standardized as:
  - `scripts/00-common.sh`
  - `scripts/01-seed-draft-review-vault-secrets.sh`
  - `scripts/02-validate-draft-review-k3s.sh`
  - `scripts/03-export-hosted-draft-review-db.sh`
  - `scripts/04-snapshot-k3s-draft-review-db.sh`
  - `scripts/05-import-draft-review-data-into-k3s.sh`
  - `scripts/06-rewrite-draft-review-wesen-identity.sh`
  - `scripts/07-validate-draft-review-data-migration.sh`
- Live data-migration lessons:
  - normalize PostgreSQL 18 dump headers before replay into the cluster restore path
  - rebuild legacy table exports against the target schema when source columns no longer exist
  - prefer `kubectl cp` plus `psql -f` over long SQL streams through `kubectl exec -i`

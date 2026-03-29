# Tasks

## TODO

- [x] Inspect the current Coolify runtime contract and source-repo deployment assumptions
- [x] Write the Draft Review K3s migration design and implementation guide
- [x] Write the migration playbook and initial diary
- [x] Package the Draft Review source repo for GHCR publishing and CI-created GitOps PRs
- [ ] Add the Draft Review parallel Keycloak env in the Terraform repo
- [ ] Add the Draft Review GitOps package in this repo
- [ ] Add Vault runtime secret delivery for Draft Review
- [ ] Add the Vault-backed private GHCR pull-secret path for Draft Review
- [ ] Add a Postgres bootstrap job and create the `draft_review` database/user on shared Postgres
- [ ] Add persistent media storage wiring for Draft Review uploads
- [ ] Deploy the Draft Review Argo CD application
- [ ] Validate health, OIDC login, database-backed behavior, and media persistence
- [ ] Update the canonical deployment docs if the real migration exposes gaps in the current guidance

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

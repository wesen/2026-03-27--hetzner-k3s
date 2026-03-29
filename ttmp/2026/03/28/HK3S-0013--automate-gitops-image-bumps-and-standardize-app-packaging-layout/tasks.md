# Tasks

## TODO

- [x] Inventory the current app packaging and image-release patterns across the K3s repo and at least one app repo
- [x] Define the target app packaging contract for public apps, platform apps, and shared data services
- [x] Design a CI-driven workflow that opens GitOps pull requests to bump immutable image tags instead of requiring manual edits
- [x] Specify repository, credential, rollback, and review boundaries for the GitHub Actions plus GitOps PR model
- [x] Document the phased implementation plan and recommended rollout order for adopting the pattern across services
- [x] Write the operator-facing packaging standard and CI-created GitOps PR guide in `docs/`
- [x] Add concrete implementation tasks and validation notes for the `mysql-ide` rollout path
- [x] Add deployment target metadata to the `mysql-ide` app repo for the CoinVault destination
- [x] Add a deterministic updater script in the `mysql-ide` repo that can patch a GitOps manifest, create a branch, and open a PR
- [x] Extend the `mysql-ide` GitHub Actions release pipeline to invoke the GitOps PR workflow on successful `main` builds
- [x] Validate the updater locally against a temporary clone of this GitOps repo and document the exact required GitHub secret boundary
- [x] Update the ticket diary and changelog with the implementation results
- [ ] Configure `GITOPS_PR_TOKEN` in the `wesen/2026-03-27--mysql-ide` GitHub repository and verify the first real CI-created pull request into this GitOps repo

## Notes

- Recommended first implementation target: `mysql-ide`
- Recommended first GitOps target file: `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml`
- Keep Argo CD Image Updater out of the first implementation slice
- The remaining live-proof step is GitHub secret configuration, not local tooling

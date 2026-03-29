# Tasks

## TODO

- [ ] Inventory the current app packaging and image-release patterns across the K3s repo and at least one app repo
- [ ] Define the target app packaging contract for public apps, platform apps, and shared data services
- [ ] Design a CI-driven workflow that opens GitOps pull requests to bump immutable image tags instead of requiring manual edits
- [ ] Specify repository, credential, rollback, and review boundaries for the GitHub Actions plus GitOps PR model
- [ ] Document the phased implementation plan and recommended rollout order for adopting the pattern across services

## Notes

- Recommended first implementation target: `mysql-ide`
- Recommended first GitOps target file: `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml`
- Keep Argo CD Image Updater out of the first implementation slice

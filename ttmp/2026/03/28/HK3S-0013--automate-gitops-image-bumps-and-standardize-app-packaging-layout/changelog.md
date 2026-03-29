# Changelog

## 2026-03-28

- Initial workspace created


## 2026-03-28

Added the initial design package for CI-created GitOps pull requests and standardized app packaging layout, grounded in the current mysql-ide GHCR workflow and the existing GitOps package shapes.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/28/HK3S-0013--automate-gitops-image-bumps-and-standardize-app-packaging-layout/design-doc/01-ci-created-gitops-pull-requests-and-standard-app-packaging-layout.md — Primary design document
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/28/HK3S-0013--automate-gitops-image-bumps-and-standardize-app-packaging-layout/playbook/01-implementation-plan-for-gitops-pr-automation-and-app-packaging-standardization.md — Implementation plan
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/28/HK3S-0013--automate-gitops-image-bumps-and-standardize-app-packaging-layout/reference/01-investigation-diary-for-gitops-pr-automation-and-packaging-standardization.md — Research trail


## 2026-03-29

Started implementation by converting the ticket into a concrete worklist and writing the operator-facing package and GitOps PR standard in docs/.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/app-packaging-and-gitops-pr-standard.md — New operator-facing standard for app repo packaging and CI-created GitOps pull requests
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/28/HK3S-0013--automate-gitops-image-bumps-and-standardize-app-packaging-layout/reference/01-investigation-diary-for-gitops-pr-automation-and-packaging-standardization.md — Implementation diary update
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/28/HK3S-0013--automate-gitops-image-bumps-and-standardize-app-packaging-layout/tasks.md — Expanded implementation task list


## 2026-03-29

Packaged `mysql-ide` as the first concrete app-repo implementation of the new standard by adding deployment target metadata, a deterministic GitOps manifest updater, and a release workflow stage that can open pull requests once the GitHub secret is configured.

### Related Files

- /home/manuel/code/wesen/2026-03-27--mysql-ide/deploy/gitops-targets.json — First explicit deployment-target map for CI-created GitOps pull requests
- /home/manuel/code/wesen/2026-03-27--mysql-ide/scripts/open_gitops_pr.py — Deterministic manifest patcher and pull-request helper
- /home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml — Release workflow extended with the `gitops-pr` job
- /home/manuel/code/wesen/2026-03-27--mysql-ide/README.md — Operator docs for the new target metadata and secret boundary
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/28/HK3S-0013--automate-gitops-image-bumps-and-standardize-app-packaging-layout/reference/01-investigation-diary-for-gitops-pr-automation-and-packaging-standardization.md — Recorded local dry-run validation and the remaining live-proof step

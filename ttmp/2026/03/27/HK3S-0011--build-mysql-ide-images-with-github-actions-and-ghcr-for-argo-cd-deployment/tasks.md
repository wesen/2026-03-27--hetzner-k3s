# Tasks

## Phase 1: Analyze the current image path and define the target operating model

- [x] Inspect the current `mysql-ide` deployment manifest in the K3s repo
- [x] Inspect the current local image import script and its assumptions
- [x] Confirm the `mysql-ide` app repo now has a real GitHub remote
- [x] Check whether the app repo already has GitHub Actions in place
- [x] Compare the manual node-local flow with a registry-backed CI flow
- [x] Document the recommended end-state and rejected alternatives

## Phase 2: Design the GitHub Actions build and publish workflow

- [x] Define the recommended GitHub Actions trigger model:
  - `pull_request` for test/build validation
  - `push` to `main` for publish
- [x] Define the GitHub Actions permission model:
  - `contents: read`
  - `packages: write`
- [x] Define how the workflow should authenticate to GHCR
- [x] Define the image naming convention under `ghcr.io`
- [x] Define the tagging strategy:
  - immutable commit SHA tag
  - optional branch tag
  - optional `latest`
- [x] Decide whether the package should be public or private
- [x] Document how to fall back to a pull secret if private visibility is chosen later

## Phase 3: Design the K3s and GitOps deployment changes

- [x] Define how the deployment manifest should change from:
  - `imagePullPolicy: Never`
  - node-local image name
  to:
  - registry image reference
  - normal pull policy
- [x] Define the recommended immutable image reference format in Kustomize
- [x] Decide how Git should become the deployment source of truth after image publication
- [x] Evaluate whether to update image tags manually in Git, by CI-created PR, or by Argo CD Image Updater
- [x] Recommend the initial rollout strategy and explain why

## Phase 4: Write the intern-facing design and implementation guide

- [x] Create a detailed design document that explains:
  - the current manual path
  - the target CI/registry/GitOps path
  - the responsibilities of GitHub Actions, GHCR, GitOps, and Argo CD
  - the alternatives and tradeoffs
- [x] Create a detailed implementation playbook with concrete task ordering
- [x] Create a chronological investigation diary for the ticket
- [x] Add file relationships with `docmgr doc relate`
- [x] Validate the ticket with `docmgr doctor`
- [x] Upload the ticket bundle to reMarkable

## Phase 5: Future implementation tasks after this design ticket

- [ ] Add a GitHub Actions workflow to `/home/manuel/code/wesen/2026-03-27--mysql-ide`
- [ ] Push `mysql-ide` images to GHCR on `main`
- [ ] Update the K3s deployment to pull from GHCR
- [ ] Remove `imagePullPolicy: Never` and the manual node-import requirement from the normal path
- [ ] Decide whether to keep tag bumps manual, CI-driven through PRs, or automated with Argo CD Image Updater

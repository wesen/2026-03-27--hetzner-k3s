# Tasks

## Phase 1: Investigate the current operator workflow

- [x] Inspect the K3s repo playbooks for the current source -> GHCR -> GitOps -> Argo model
- [x] Inspect the current `pretext-trace` GitOps package and Argo application shape
- [x] Inspect the live source-repo CI-created GitOps PR pattern from `mysql-ide` and `pretext-wasm`
- [x] Capture the real command sequences and polling loops used during the `pretext-trace` rollout

## Phase 2: Design the CLI

- [x] Define the problem as orchestration fragmentation across GitHub, GHCR, GitOps, Kubernetes, Argo CD, ingress auth, and public verification
- [x] Propose a target model for a single operator-facing release CLI
- [x] Define the command tree, target registry shape, and major workflows
- [x] Decide what should shell out to existing tools in phase 1 versus use native clients later

## Phase 3: Write the ticket deliverables

- [x] Write a detailed design and implementation guide for a new intern
- [x] Write a detailed investigation diary with real commands and failure scenarios
- [x] Relate the most important repo files to the new docs
- [x] Update the ticket changelog with the new design deliverables

## Phase 4: Validate and publish

- [x] Run `docmgr doctor` and fix any vocabulary issues
- [x] Upload the final document bundle to reMarkable
- [x] Verify the uploaded bundle exists in the expected remote directory

---
Title: Diary
Ticket: HK3S-0001
Status: active
Topics:
    - infra
    - kubernetes
    - terraform
    - gitops
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: .gitignore
      Note: Prevents IDE-local state from leaking into git checkpoints
    - Path: .ttmp.yaml
      Note: Docmgr workspace configuration used by the ticket
    - Path: README.md
      Note: Repository context that informed the first deployment step
    - Path: ttmp/vocabulary.yaml
      Note: Extended with deployment-related topics for this ticket
ExternalSources: []
Summary: Step-by-step diary of ticket setup, deployment execution, questions, and outcomes.
LastUpdated: 2026-03-27T07:57:29.536192903-04:00
WhatFor: Preserve the chronological deployment narrative, including decisions, blockers, exact commands, and validation guidance.
WhenToUse: Update after each meaningful deployment step so another operator can reconstruct the rollout and review it quickly.
---


# Diary

## Goal

Capture the deployment of this repository to Hetzner as an ordered, reviewable sequence. Each step records what changed, why it was necessary, what blocked progress, and how to validate the result.

## Step 1: Create the deployment ticket and operator workflow

I created a dedicated docmgr ticket so this deployment has a durable control point instead of living only in shell history. The goal of this step was to turn the repository into a guided rollout with an explicit current step, a runbook, a task list, and a diary that can be updated after every meaningful action.

I also adjusted the workflow to include incremental git commits, because the user asked that progress be checkpointed as it happens. Since the repository started entirely uncommitted, the main care point was keeping IDE-local state out of the initial checkpoint while still allowing the actual project files to be committed.

### Prompt Context

**User prompt (verbatim):** "Create a new docmgr ticket to deploy this setup to hetzner, step by step, explaining to me what the current step is (and writing it up in your diary at each step) and asking me whatever needs to be answer."

**Follow-up user prompt (verbatim):** "make sure to commit things to git as you go as well."

**Follow-up user prompt (verbatim):** "you can check in all the initial files too"

**Assistant interpretation:** Create a deployment ticket for this repository, drive the rollout step by step, explain the active stage, and maintain a chronological diary as the work progresses.

**Inferred user intent:** Make the Hetzner deployment operationally explicit, inspectable, and easy to continue or review later.

### What I did
- Read the repository layout and `README.md` to identify the actual deployment sequence and external requirements.
- Read the `docmgr` and `diary` skill instructions and verified that this repo already had a configured `ttmp/` workspace.
- Added the missing ticket topics `infra`, `kubernetes`, `terraform`, and `gitops` to the local docmgr vocabulary.
- Created ticket `HK3S-0001` with a deployment plan, runbook, and diary.
- Replaced the empty generated templates with repo-specific content and a concrete task list.
- Added `.idea/` to `.gitignore` so local editor state does not leak into the initial commit.

### Why
- The deployment needs a tracked operating document before infrastructure changes begin.
- The repo requires several environment-specific values that cannot be inferred locally.
- Incremental git commits only help if the staged content is deliberate and reviewable.

### What worked
- `docmgr` was already initialized for this repo, so the ticket scaffold and supporting docs could be created cleanly.
- The repository README and Terraform variable definitions made the required deployment inputs clear without additional external research.

### What didn't work
- A plain `git add .` was not safe at the start of this step because the entire repository was untracked and included local IDE files under `.idea/`.
- My first frontmatter validation attempt used `docmgr validate frontmatter --doc ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/index.md --suggest-fixes`, which failed because `docmgr` resolved `--doc` relative to the docs root and looked for `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/ttmp/...`.

### What I learned
- The simplest supported bootstrap path is a public Git repository that both cloud-init and Argo CD can read directly.
- The blocking operator inputs are Hetzner credentials, SSH key material, admin CIDRs, Git repo details, DNS/domain settings, ACME email, and the PostgreSQL password.

### What was tricky to build
- The sharp edge was Git hygiene in a fully untracked repository. The symptom was that any broad staging command would have mixed local state, project source, and freshly created docmgr files together. I handled that by reading the generated ticket paths first, tightening `.gitignore`, and planning a targeted initial commit that includes project sources and ticket docs but excludes editor-only metadata.
- The other sharp edge was `docmgr` path resolution for validation. The symptom was a duplicated `ttmp/ttmp/...` path in the error output. The fix was to pass absolute document paths when validating frontmatter.

### What warrants a second pair of eyes
- The ticket naming choice `HK3S-0001` and the newly added topic vocabulary are sensible local defaults, but they should be renamed now if you have a stronger project-wide convention.
- The runbook currently assumes the public-repo bootstrap path described in the README. If you intend to use a private repository, the later steps will need to include Argo CD repo credentials.

### What should be done in the future
- Collect the operator-provided deployment values.
- Create the initial repository checkpoint in git.
- Prepare `terraform.tfvars` and move to the Terraform apply step.

### Code review instructions
- Start with `ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/index.md`, `ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/design-doc/01-deployment-plan.md`, and `ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/playbook/01-deployment-runbook.md`.
- Validate the ticket shape with `docmgr ticket list --ticket HK3S-0001`, `docmgr doc list --ticket HK3S-0001`, and `docmgr validate frontmatter --doc /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md --suggest-fixes`.

### Technical details
- Commands run:
  - `docmgr status --summary-only`
  - `docmgr vocab add --category topics --slug infra --description 'Infrastructure and provisioning'`
  - `docmgr vocab add --category topics --slug kubernetes --description 'Kubernetes cluster bootstrap and operations'`
  - `docmgr vocab add --category topics --slug terraform --description 'Terraform infrastructure definitions and workflow'`
  - `docmgr vocab add --category topics --slug gitops --description 'GitOps bootstrapping and Argo CD deployment flow'`
  - `docmgr ticket create-ticket --ticket HK3S-0001 --title 'Deploy Hetzner K3s Demo' --topics infra,kubernetes,terraform,gitops`
  - `docmgr doc add --ticket HK3S-0001 --doc-type design-doc --title 'Deployment Plan'`
  - `docmgr doc add --ticket HK3S-0001 --doc-type playbook --title 'Deployment Runbook'`
  - `docmgr doc add --ticket HK3S-0001 --doc-type reference --title 'Diary'`
  - `docmgr validate frontmatter --doc /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/index.md --suggest-fixes`

---
Title: Implementation diary
Ticket: HK3S-0003
Status: active
Topics:
    - vault
    - k3s
    - argocd
    - gitops
    - migration
DocType: reference
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: "Chronological implementation diary for recreating Vault on the K3s cluster via Argo CD."
LastUpdated: 2026-03-27T11:38:00-04:00
WhatFor: "Use this to review each implementation step, the exact commands run, and why the repo and cluster changed the way they did."
WhenToUse: "Read this when continuing implementation or reviewing the execution trail after the fact."
---

# Implementation diary

## Goal

Capture the implementation work for bringing up a new Vault deployment on K3s through Argo CD, while keeping the existing Coolify Vault untouched during this ticket.

## Step 1: Refine scope and turn the design into executable tasks

The design ticket covered a full migration path, including eventual consumer cutover. Before touching the repo or cluster, I narrowed the implementation scope based on the user’s clarification: the immediate need is not to move or dismantle the Coolify side, but to recreate the Vault deployment on K3s cleanly. That changes the execution order. It means the right first deliverable is a new implementation ticket with a task list that ends at “new K3s Vault is deployed and validated,” not “all old dependencies are removed.”

I used that scope refinement to create `HK3S-0003`, add the implementation playbook and diary, and write a detailed task list that splits the work into scaffold, bootstrap, deploy, verify, and initialize phases. I also gathered the concrete external facts needed for real implementation: `vault.yolo.scapegoat.dev` already resolves to the K3s node, the local AWS profile works, the Coolify host is reachable, the current live Vault container exposes the AWS KMS environment needed for auto-unseal, and the current official Vault chart version is `0.32.0`.

### Prompt Context

**User prompt (verbatim):** "ok, create a detailed set of tasks to tackle the feature. We don't need to move the coolify stuff, more so than recreate the deployments, btw. 

Then work on the tasks one by one, committing at appropriate intervals, and keeping a detailed diary as you wokr"

**Assistant interpretation:** Create a separate implementation ticket, translate the earlier design into a concrete ordered task list, and then start executing those tasks with focused commits and diary updates.

**Inferred user intent:** Start real implementation now, but avoid over-scoping into cutover or cleanup work that can happen later.

### What I did
- Created ticket `HK3S-0003`.
- Added:
  - `playbook/01-vault-on-k3s-implementation-plan.md`
  - `reference/01-implementation-diary.md`
- Wrote the ordered implementation task list in `tasks.md`.
- Verified:
  - `vault.yolo.scapegoat.dev` resolves to `91.98.46.169`
  - local AWS access works through profile `manuel`
  - the Coolify host is reachable
  - the live Vault container still uses AWS KMS auto-unseal env vars
  - the current official HashiCorp Vault chart version is `0.32.0`
- Inspected the official chart values and ingress template to confirm the shape of the first Argo application.

### Why
- The repo and diary should reflect the implementation slice we are actually executing, not the whole eventual migration.
- I needed to confirm that a real deployment was feasible before writing cluster manifests.

### What worked
- DNS and cluster hostname coverage are already in place through the wildcard record.
- The local AWS profile works, which means auxiliary validation and Terraform-side follow-up are feasible from this machine.
- The current live Vault deployment exposes the exact AWS env contract we need to recreate.
- The official chart is accessible and inspectable without installing Helm locally.

### What didn't work
- `helm` is not installed locally:

```text
zsh:1: command not found: helm
```

- I worked around that by downloading the official chart tarball directly from `https://helm.releases.hashicorp.com`.

- One remote env inspection initially failed because `rg` was not installed on the Coolify host:

```text
bash: line 1: rg: command not found
```

- I reran the command using local `grep` after the SSH pipe instead.

- The first attempt to run `vault auth list` inside the live container failed with a 403 because the container did not have a privileged token in environment:

```text
Error listing enabled authentications: Error making API request.

URL: GET https://vault.app.scapegoat.dev/v1/sys/auth
Code: 403. Errors:

* permission denied
```

- That was informative but not blocking for this step.

### What I learned
- The right boundary for this ticket is deployment recreation, not migration cutover.
- `vault.yolo.scapegoat.dev` is already the correct first target hostname.
- The live Coolify Vault confirms the KMS alias and AWS env names we should preserve in K3s.

### What was tricky to build
- The main tricky part was resisting the temptation to immediately implement the full design from `HK3S-0002`. That would have mixed deployment, auth hardening, VSO install, and app-secret recreation into one overly wide ticket. The user’s clarification changed the correct sequencing: first make K3s Vault real, then build on top of it.

### What warrants a second pair of eyes
- Whether the first Argo application should include only the Vault server, or whether enabling additional chart components like the injector belongs in the first deploy. My current view is to keep the first deploy narrow and disable injector/CSI for now.

### What should be done in the future
- Implement the repo-managed Vault application scaffold next.
- Add the bootstrap secret helper and then deploy the application.

### Code review instructions
- Review:
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0003--implement-vault-on-k3s-via-argo-cd/tasks.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0003--implement-vault-on-k3s-via-argo-cd/tasks.md)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0003--implement-vault-on-k3s-via-argo-cd/playbook/01-vault-on-k3s-implementation-plan.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0003--implement-vault-on-k3s-via-argo-cd/playbook/01-vault-on-k3s-implementation-plan.md)
- Confirm the task ordering is realistic for a first K3s deployment without cutover.

### Technical details
- Commands run:
  - `dig +short vault.yolo.scapegoat.dev`
  - `aws sts get-caller-identity --profile manuel`
  - `ssh -o BatchMode=yes root@89.167.52.236 'docker ps --format "{{.Names}}" | sed -n "1,40p"'`
  - `ssh -o BatchMode=yes root@89.167.52.236 "docker inspect vault-o1354vyfl0wveue81q9mroc8 --format '{{range .Config.Env}}{{println .}}{{end}}'" | grep -E '^(AWS_|VAULT_)'`
  - `ssh -o BatchMode=yes root@89.167.52.236 "docker exec vault-o1354vyfl0wveue81q9mroc8 sh -lc 'cat /vault/config/vault.hcl'"`
  - `python - <<'PY' ... urllib.request.urlopen('https://helm.releases.hashicorp.com/index.yaml') ... PY`
  - `curl -sSL https://helm.releases.hashicorp.com/vault-0.32.0.tgz | tar -xzO vault/values.yaml`

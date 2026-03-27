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
RelatedFiles:
    - Path: README.md
      Note: Top-level operator discovery docs for the Vault bootstrap path (commit ec36585)
    - Path: gitops/applications/vault.yaml
      Note: Repo-managed Argo CD Application for the first Vault deployment scaffold (commit ec36585)
    - Path: scripts/bootstrap-vault-aws-kms-secret.sh
      Note: Local helper for the non-git AWS KMS bootstrap secret (commit ec36585)
ExternalSources: []
Summary: Chronological implementation diary for recreating Vault on the K3s cluster via Argo CD.
LastUpdated: 2026-03-27T11:38:00-04:00
WhatFor: Use this to review each implementation step, the exact commands run, and why the repo and cluster changed the way they did.
WhenToUse: Read this when continuing implementation or reviewing the execution trail after the fact.
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

## Step 2: Add the Vault scaffold to the repo and keep secrets out of git

This step turned the plan into actual repo state. I added a repo-managed Argo CD `Application` for Vault, using the official HashiCorp Helm chart directly from the Helm repository, and encoded the first-pass deployment choices inline so they are reviewable in one place. The first deploy stays intentionally narrow: one Vault server pod, Raft on `local-path`, Traefik ingress, cert-manager TLS, and AWS KMS auto-unseal via environment variables read from a Kubernetes `Secret`.

I also added a local bootstrap script for that AWS secret rather than baking credentials into Git or into the chart values. That keeps the deployment declarative where it should be declarative, while preserving a clean operational boundary around secrets. The validation story for this step was mixed: the shell script and YAML both validated locally, but live `kubectl` checks against the Hetzner cluster hung, so I recorded that as an environmental issue instead of pretending the cluster-side validation was complete.

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Implement the first executable Vault deployment slice, starting with the repo-managed scaffold and documenting the work as it happens.

**Inferred user intent:** Make visible, reviewable progress toward a real K3s Vault deployment without smuggling credentials into git or collapsing planning and implementation together.

**Commit (code):** ec36585 — "feat: add vault argocd deployment scaffold"

### What I did
- Added [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault.yaml) as the repo-managed Argo CD `Application` for Vault.
- Chose the first-pass chart values:
  - chart `vault` version `0.32.0`
  - single replica in HA+Raft mode
  - `local-path` data PVC
  - ingress on `vault.yolo.scapegoat.dev`
  - Traefik + cert-manager TLS
  - AWS KMS seal stanza for `alias/vault-scapegoat-dev-unseal`
  - injector disabled
  - CSI disabled
- Added [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-aws-kms-secret.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-aws-kms-secret.sh) to create or update the non-git `vault-aws-kms` secret in namespace `vault`.
- Updated [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/README.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/README.md) so the new Vault application and bootstrap path are discoverable.
- Validated:
  - `bash -n scripts/bootstrap-vault-aws-kms-secret.sh`
  - `git diff --check`
  - `ruby -e 'require "yaml"; YAML.load_file("gitops/applications/vault.yaml")'`

### Why
- Vault needs a durable GitOps definition before the live rollout is touched.
- The AWS credential material must stay outside git, but the operator flow for creating it should still be reproducible.
- Using the official chart directly is the shortest path to a correct first deployment while keeping room for later refactoring if we decide to replace Helm with a Kustomize-owned rendered package.

### What worked
- The shell helper validated cleanly.
- The new `Application` manifest parses as YAML and has the expected chart/source shape.
- The repo now has a clear split between declarative deployment state and non-git secret bootstrap.

### What didn't work
- A plain `kubectl` validation attempt initially used the wrong local context and failed against `kubernetes.docker.internal:6443`:

```text
E0327 13:09:01.349755 1578252 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://kubernetes.docker.internal:6443/api?timeout=32s\": dial tcp 127.0.0.1:6443: connect: connection refused"
error: unable to recognize "gitops/applications/vault.yaml": Get "https://kubernetes.docker.internal:6443/api?timeout=32s": dial tcp 127.0.0.1:6443: connect: connection refused
```

- After forcing the right kubeconfig, cluster-side checks still hung and timed out instead of returning quickly:

```text
timeout 15s env KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl cluster-info
```

returned exit code `124` with no usable output.

### What I learned
- The repo-side scaffold is small enough to keep straightforward if the secret contract is explicit.
- It is safer to keep the AWS credential bootstrap as a separate local script than to over-abstract it into Terraform or cloud-init for this ticket.
- Live cluster validation is currently blocked by API responsiveness, not by obvious local manifest problems.

### What was tricky to build
- The main design tension was how much of Vault’s eventual shape to encode in the first deploy. Using HA mode with a single replica looks odd at first, but it keeps the integrated Raft configuration aligned with the long-term intended Vault mode without introducing multi-node scheduling requirements on a one-node cluster. The narrower alternative would have been standalone mode, but that would have changed the storage and service model we expect to carry forward.

### What warrants a second pair of eyes
- Whether the ingress should continue targeting the general server service (`activeService: false`) for pre-init reachability, or whether we should switch to an active-only path after the deployment is stable.
- Whether enabling `auditStorage` belongs in the first deploy or should stay deferred until after initialization and auth setup.

### What should be done in the future
- Bootstrap the live `vault-aws-kms` secret in the cluster.
- Apply the Vault `Application` and observe the first rollout.
- Re-check cluster API responsiveness before relying on `kubectl`-side validation results.

### Code review instructions
- Review:
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault.yaml)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-aws-kms-secret.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-aws-kms-secret.sh)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/README.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/README.md)
- Validate locally with:
  - `bash -n scripts/bootstrap-vault-aws-kms-secret.sh`
  - `ruby -e 'require "yaml"; YAML.load_file("gitops/applications/vault.yaml")'`
- Validate against the cluster once the API responds again:
  - `export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml`
  - `kubectl apply --dry-run=server -f gitops/applications/vault.yaml`

### Technical details
- Commands run:
  - `chmod +x scripts/bootstrap-vault-aws-kms-secret.sh`
  - `bash -n scripts/bootstrap-vault-aws-kms-secret.sh`
  - `kubectl apply --dry-run=client --validate=false -f gitops/applications/vault.yaml`
  - `timeout 15s env KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl cluster-info`
  - `ruby -e 'require "yaml"; data = YAML.load_file("gitops/applications/vault.yaml"); abort("wrong kind") unless data["kind"] == "Application"; puts data.dig("spec", "source", "chart")'`

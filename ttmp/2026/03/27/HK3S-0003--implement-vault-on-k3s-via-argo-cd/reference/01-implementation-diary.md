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
LastUpdated: 2026-03-27T13:19:00-04:00
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

## Step 3: Recover admin access drift and complete the live Vault rollout

This step started with an operator access problem rather than a chart problem. The repo-side scaffold was ready, but both SSH and the Kubernetes API had become unreachable from this workstation. The actual cause was a stale firewall allowlist: `admin_cidrs` still pointed at an earlier public IP while the current workstation IP had changed. I corrected that with a targeted Terraform firewall apply, restored cluster access, and only then continued with the live Vault rollout.

Once access was back, the deployment path itself was straightforward. I created the `vault-aws-kms` bootstrap secret in namespace `vault`, applied the repo-managed `vault` Argo CD `Application`, and watched the rollout converge. The pod scheduled cleanly, the Raft PVC bound, the ingress appeared, the certificate issued, and the public health endpoint returned `503` before initialization, which is the expected signal that Vault is reachable but not initialized yet.

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Continue through the implementation tasks, handling real operational blockers as they appear rather than stopping at the scaffold.

**Inferred user intent:** End up with a live K3s Vault deployment, not just manifests in git.

### What I did
- Identified that the workstation public IP had changed to `100.40.113.156`.
- Confirmed the old firewall allowlist still only permitted `98.175.153.62/32`.
- Updated the local-only `terraform.tfvars` admin CIDR and ran a targeted `terraform apply -target=hcloud_firewall.default -auto-approve`.
- Revalidated access with:
  - `kubectl cluster-info`
  - `ssh root@91.98.46.169 'kubectl get nodes -o wide'`
- Pulled the existing Vault AWS KMS credentials from the current Coolify Vault container.
- Created the live `vault-aws-kms` secret with [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-aws-kms-secret.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-aws-kms-secret.sh).
- Applied [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault.yaml).
- Verified:
  - Argo CD `Application` reached `Synced`
  - `vault-0` pod was `Running`
  - `data-vault-0` PVC bound
  - ingress existed on `vault.yolo.scapegoat.dev`
  - cert-manager certificate became `Ready`
  - `curl -k https://vault.yolo.scapegoat.dev/v1/sys/health` returned `503` before init

### Why
- Access had to be restored before any live deployment step was possible.
- The targeted firewall apply was the lowest-risk operational fix.
- The AWS KMS secret needed to exist before Argo could start Vault with the intended seal configuration.

### What worked
- The firewall-only Terraform apply restored both SSH and Kubernetes API access.
- The official Vault chart deployed cleanly under Argo CD.
- Pod scheduling, PVC binding, ingress creation, and certificate issuance all worked on the first pass after access was restored.
- The public `503` health response correctly reflected “reachable but not initialized.”

### What didn't work
- Cluster access from this workstation failed until the admin CIDR was updated.
- The failure mode looked like hanging `kubectl` and SSH timeouts rather than a clean firewall message, so the diagnosis required checking the current public IP explicitly.

### What I learned
- Single-IP admin allowlists are workable for a demo but brittle for real operator workflows.
- The live Vault rollout path is mechanically simple once cluster access is stable.
- `503` from `/v1/sys/health` is a useful expected-state signal during pre-init.

### What was tricky to build
- The main tricky part was avoiding a false root cause. It would have been easy to blame the Vault chart or Argo CD when the real issue was the operator machine falling outside the firewall allowlist. Restoring access first kept the deployment debugging honest.

### What warrants a second pair of eyes
- Whether this environment should keep relying on changing home-IP allowlists for SSH and Kubernetes API access.
- Whether the K3s Vault should keep reusing the legacy deployment’s AWS KMS credentials or move to a cleaner dedicated IAM identity.

### What should be done in the future
- Replace brittle per-IP admin access with a more stable operator boundary.
- Create a dedicated AWS IAM principal for the K3s Vault seal path if stronger separation is needed.

### Code review instructions
- Review:
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault.yaml)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-aws-kms-secret.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-aws-kms-secret.sh)
- Validate with:
  - `export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml`
  - `kubectl -n argocd get application vault`
  - `kubectl -n vault get pods,pvc,ingress`
  - `kubectl -n vault get certificate`
  - `curl -k https://vault.yolo.scapegoat.dev/v1/sys/health`

### Technical details
- Commands run:
  - `curl -s https://api.ipify.org`
  - `terraform plan -target=hcloud_firewall.default -no-color`
  - `terraform apply -target=hcloud_firewall.default -auto-approve`
  - `ssh -o BatchMode=yes root@91.98.46.169 'kubectl get nodes -o wide'`
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml ./scripts/bootstrap-vault-aws-kms-secret.sh`
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl apply -f gitops/applications/vault.yaml`
  - `kubectl -n vault describe pod vault-0`
  - `kubectl -n vault logs vault-0 --tail=120`
  - `kubectl -n vault get certificate,challenge,order`
  - `curl -k -I https://vault.yolo.scapegoat.dev/`

## Step 4: Initialize Vault once, store recovery material in 1Password, and verify auto-unseal

After the deployment reached the expected pre-init state, I performed the one irreversible operator step in this ticket: initializing the new Vault. Because the deployment uses AWS KMS auto-unseal, initialization produced recovery keys rather than an ongoing manual unseal workflow. I captured the init JSON locally, wrote it immediately into a 1Password secure note in the `Private` vault, and let the shell delete the temporary local files on exit. Nothing sensitive was written into repo docs, repo files, or left on the server.

Then I verified the actual operating behavior instead of stopping at “init succeeded.” The public health endpoint returned `200`, the UI responded on `https://vault.yolo.scapegoat.dev/ui/`, and a forced deletion of `vault-0` proved that the replacement pod came back `initialized=true` and `sealed=false` on its own. That is the concrete confirmation that AWS KMS auto-unseal is functioning, not merely configured.

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Complete the one-time Vault bring-up safely and prove the resulting deployment is recoverable.

**Inferred user intent:** Finish this ticket with a real, usable Vault on K3s rather than a pod that still needs manual bootstrap work.

### What I did
- Checked pre-init status with `vault status -format=json`.
- Ran `vault operator init -format=json` exactly once in `vault-0`.
- Stored the root token, recovery keys, and raw init JSON in 1Password vault `Private` as secure note `vault yolo scapegoat dev k3s init 2026-03-27`.
- Verified post-init state:
  - `initialized=true`
  - `sealed=false`
  - public health endpoint returned `200`
  - `https://vault.yolo.scapegoat.dev/ui/` returned `HTTP/2 200`
- Deleted `vault-0` and waited for the replacement pod to come back.
- Verified the restarted pod auto-unsealed and the application remained `Synced Healthy` in Argo CD.

### Why
- Initialization is the required one-time transition from “reachable Vault server” to “usable Vault cluster.”
- Recovery material had to leave both the repo and the server immediately.
- Restart verification is the strongest proof that the AWS KMS auto-unseal path works operationally.

### What worked
- The initialization command succeeded on the first try.
- 1Password was available through the CLI, so the secure note storage path stayed local-to-operator and off-cluster.
- The restarted pod came back `Ready` and unsealed without manual intervention.
- Argo CD reported `sync=Synced health=Healthy` after the restart.

### What didn't work
- `vault status -format=json` returned exit code `2` before init because the server was sealed and uninitialized. That was expected behavior, but it is easy to misread as a generic command failure if not documented.

### What I learned
- This design works cleanly on the current single-node K3s stack: Argo deployment, Raft, Traefik TLS, and AWS KMS auto-unseal all fit together without extra bootstrap hacks.
- For this stage, 1Password is a reasonable off-cluster escrow for recovery material.
- Forced pod deletion is the right validation step for auto-unseal; a static post-init `vault status` is not enough.

### What was tricky to build
- The sharp edge was handling the init material safely. Initialization necessarily emits the most sensitive material in the system. The correct pattern was to treat local disk as a short-lived transit path only: write temp files, create the 1Password secure note immediately, verify it exists, and let the shell `trap` clean up the files.

### What warrants a second pair of eyes
- Whether the 1Password item naming convention used here is the long-term convention we want for future environments.
- Whether we want a second reviewed backup path for recovery material before onboarding more workloads.

### What should be done in the future
- Enable human login through Keycloak OIDC.
- Enable Kubernetes auth and baseline Vault policies.
- Deploy Vault Secrets Operator and verify in-cluster secret sync.
- Recreate the first application deployment against Vault-managed secrets.

### Code review instructions
- Validate with:
  - `export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml`
  - `kubectl -n vault exec vault-0 -- sh -lc 'vault status -format=json'`
  - `curl -k https://vault.yolo.scapegoat.dev/v1/sys/health`
  - `curl -k -I https://vault.yolo.scapegoat.dev/ui/`
  - `kubectl -n argocd get application vault -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{"\n"}'`
- Confirm that recovery material is not present in the repo and that the secure note exists in 1Password.

### Technical details
- Commands run:
  - `kubectl -n vault exec vault-0 -- sh -lc 'vault status -format=json'`
  - `kubectl -n vault exec vault-0 -- sh -lc 'vault operator init -format=json'`
  - `op item template get 'Secure Note'`
  - `op item create --vault Private --tags vault,k3s,bootstrap -`
  - `op item get 'vault yolo scapegoat dev k3s init 2026-03-27' --vault Private --format json`
  - `curl -k -sS -o /dev/null -w '%{http_code} %{content_type}\n' https://vault.yolo.scapegoat.dev/v1/sys/health`
  - `curl -k -I https://vault.yolo.scapegoat.dev/ui/`
  - `kubectl -n vault delete pod vault-0`
  - `kubectl -n vault exec vault-0 -- sh -lc 'vault status -format=json' | jq -r '.initialized, .sealed, .leader_address'`

## Step 5: Close the ticket in a validated state

With the deployment working, the last step was to make the ticket usable as long-term project memory instead of leaving the details split across shell history and half-updated docs. I updated the ticket index, task list, playbook, changelog, and diary to reflect the finished state: live Vault on K3s, recovery material stored in 1Password, and auto-unseal verified after restart. I also recorded the recommended next tickets so the follow-up work has a clean handoff boundary.

I then ran `docmgr doctor --ticket HK3S-0003 --stale-after 30`. The first run found one vocabulary mismatch because I had used `completed` instead of `complete` in the ticket status field. I corrected that and reran doctor successfully. That closes the ticket with a clean documentation validation pass rather than an informal “looks done.”

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Finish the task list fully, including the documentation and validation work around the implementation.

**Inferred user intent:** Leave behind a ticket that someone else can trust and continue from, not just a deployed cluster object.

### What I did
- Updated the ticket docs to reflect the live completed state.
- Added the explicit next-ticket recommendations.
- Ran `docmgr doctor --ticket HK3S-0003 --stale-after 30`.
- Fixed the one reported status vocabulary mismatch.
- Reran doctor and got a clean pass.

### Why
- A deployment ticket is only really finished when the operational and documentation state agree.
- `docmgr doctor` is the lightweight quality gate that confirms the ticket is not drifting out of the repo’s documentation conventions.

### What worked
- The second doctor run passed cleanly.
- The ticket now expresses a completed implementation slice with clear next steps.

### What didn't work
- The first doctor run reported:

```text
Unknown vocabulary value for Status
Value: "completed"
Known values: draft, active, review, complete, archived
```

- That was a documentation hygiene issue, not an implementation issue.

### What I learned
- The docmgr status vocabulary is strict and worth respecting because it makes ticket state machine semantics predictable across the repo.
- A short closeout step is useful even after the technical work is done because it makes the final state auditable.

### What was tricky to build
- There was no technical trickiness here, but there was one process pitfall: it is easy to think “the cluster is healthy, so the ticket is done.” In this repo, the disciplined finish is to reconcile the docs and pass `docmgr doctor` too.

### What warrants a second pair of eyes
- The proposed next-ticket ordering: OIDC first, then Kubernetes auth/VSO, then the first app recreation.

### What should be done in the future
- Open and execute the next Vault follow-up tickets from the list in the ticket index.

### Code review instructions
- Review:
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0003--implement-vault-on-k3s-via-argo-cd/index.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0003--implement-vault-on-k3s-via-argo-cd/index.md)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0003--implement-vault-on-k3s-via-argo-cd/tasks.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0003--implement-vault-on-k3s-via-argo-cd/tasks.md)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0003--implement-vault-on-k3s-via-argo-cd/playbook/01-vault-on-k3s-implementation-plan.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0003--implement-vault-on-k3s-via-argo-cd/playbook/01-vault-on-k3s-implementation-plan.md)
- Validate with:
  - `docmgr doctor --ticket HK3S-0003 --stale-after 30`

### Technical details
- Commands run:
  - `docmgr doctor --ticket HK3S-0003 --stale-after 30`

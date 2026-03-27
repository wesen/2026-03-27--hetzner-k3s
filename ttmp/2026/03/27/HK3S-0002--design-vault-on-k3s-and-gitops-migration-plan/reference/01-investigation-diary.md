---
Title: Investigation diary
Ticket: HK3S-0002
Status: active
Topics:
    - vault
    - k3s
    - argocd
    - gitops
    - terraform
    - migration
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/docker/entrypoint.sh
      Note: Captured the current CoinVault startup contract
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/internal/bootstrap/bootstrap.go
    - Path: ../../../../../../../terraform/.envrc
      Note: Captured the current operator environment pattern and risks
    - Path: ../../../../../../../terraform/coolify/services/vault/README.md
    - Path: ../../../../../../../terraform/coolify/services/vault/docker-compose.yaml
    - Path: ../../../../../../../terraform/coolify/services/vault/scripts/provision_vault_via_coolify_host.sh
      Note: Captured the current Coolify-specific mutation path during research
    - Path: ../../../../../../../terraform/keycloak/apps/infra-access/envs/hosted/main.tf
    - Path: cloud-init.yaml.tftpl
    - Path: gitops/applications/demo-stack.yaml
      Note: Captured the current Argo application shape in the cluster repo
ExternalSources: []
Summary: Chronological investigation log for the Vault-on-K3s migration design work, including current-state evidence, live cluster inspection, and rationale for the recommended architecture.
LastUpdated: 2026-03-27T11:20:00-04:00
WhatFor: Use this to review how the conclusions in the design doc were reached and to resume the research later without repeating the same discovery work.
WhenToUse: Read this when reviewing the evidence trail, checking commands that were run, or validating that the proposed migration plan is grounded in the current live systems.
---


# Investigation diary

## Goal

Capture the chronological research trail for designing the migration from the current Coolify-hosted Vault setup toward a K3s- and Argo CD-centered platform, starting with Vault so later app migrations have a stable secret-management anchor.

## Step 1: Create the ticket and define the research scope

I started by creating a new ticket so the work would not get mixed into the already-completed Hetzner bootstrap ticket. The user asked for a detailed analysis and implementation guide, not just a quick opinion, so the right first move was to establish the document workspace, create the main design doc, create a diary, and then gather evidence before writing recommendations.

The scope was immediately clear from the prompt: investigate the current Terraform and app repos, look at `.envrc` files and previous setup diaries, inspect the live K3s server, and produce intern-friendly documentation detailed enough to guide later implementation. That means this ticket had to be evidence-first and had to capture not only the “what,” but the actual current system boundaries and migration constraints.

### Prompt Context

**User prompt (verbatim):** "Ok, let's start a new ticket. I want to move my infrastrucxture from coolify and the current semi-manual setup over to k3s and gitops argocd. 

I want to start with moving vault over to k3s and use that to provision secrets as we move further down the projects.

Look at ~/code/wesen/terraform and for example ~/code/wesen/hair-booking or ~/code/gec/2026-03-16--gec-rag on how things are setup, and do a detailed analysis on how we should best setup vault with th eplan of migrating these applicaitons over to k3s in a longer term. Look at the .envrc files and feel free to experiment / query the server and all that, and read the docs/diaries that were used to seutp the current systems. DOcument all the steps and research you do with frequent diary entries in the new ticket.

Create a detailed analysis / design / implementation guide that is very detailed for a new intern, explaining all the parts of the system needed to understand what it is, with prose paragraphs and bullet point sand pseudocode and diagrams and api references and file
  references.
  It should be very clear and detailed. Store in the ticket and the nupload to remarkable."

**Assistant interpretation:** Create a new docmgr ticket, investigate the current Vault/Coolify/K3s/application landscape in depth, and produce a detailed migration design plus implementation guidance for moving Vault onto K3s first.

**Inferred user intent:** Build a durable, intern-readable foundation for a longer migration program, with Vault as the first platform service to relocate because future app moves depend on it.

### What I did
- Read the `ticket-research-docmgr-remarkable`, `docmgr`, `diary`, and `remarkable-upload` skill instructions.
- Ran `docmgr status --summary-only`.
- Created ticket `HK3S-0002`.
- Added:
  - `design-doc/01-vault-on-k3s-and-gitops-migration-design.md`
  - `reference/01-investigation-diary.md`
  - later in the step sequence, a playbook doc for operational sequencing

### Why
- The task is bigger than a single note.
- The user explicitly asked for frequent diary entries and a final reMarkable upload.
- The design needed a stable ticket root so evidence, conclusions, and later implementation work stay connected.

### What worked
- `docmgr` ticket creation and document scaffolding worked cleanly.
- The new ticket path clearly separates this research from the completed deployment ticket.

### What didn't work
- N/A

### What I learned
- The ticket should be treated as a multi-document deliverable from the start, not retrofitted later.

### What was tricky to build
- The main challenge was scope control. The prompt spans platform architecture, current-state discovery, future migration phases, app secret-consumption patterns, and final publication. The only safe way to handle that breadth was to separate “ticket scaffolding first” from “recommendations later.”

### What warrants a second pair of eyes
- Whether the chosen ticket/document structure is enough, or whether later implementation work should split into multiple follow-up tickets immediately after this design ticket lands.

### What should be done in the future
- Once this design is accepted, create separate implementation tickets rather than turning this research ticket into a dumping ground for all subsequent migration work.

### Code review instructions
- Start with:
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/index.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/index.md)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/design-doc/01-vault-on-k3s-and-gitops-migration-design.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/design-doc/01-vault-on-k3s-and-gitops-migration-design.md)
- Confirm the ticket goal matches the user prompt before judging the technical recommendations.

### Technical details
- Commands run:
  - `docmgr status --summary-only`
  - `docmgr ticket create-ticket --ticket HK3S-0002 --title "Design Vault on K3s and GitOps Migration Plan" --topics vault,k3s,argocd,gitops,terraform,migration`
  - `docmgr doc add --ticket HK3S-0002 --doc-type design-doc --title "Vault on K3s and GitOps Migration Design"`
  - `docmgr doc add --ticket HK3S-0002 --doc-type reference --title "Investigation diary"`

## Step 2: Map the current Coolify Vault system and application secret model

I inspected the Terraform repo first because the current Vault system is defined there, not in the K3s repo. That pass quickly established that the existing Vault is already healthy and useful, but operationally it is still bound to Coolify. The most important evidence was not the existence of Vault alone; it was the shape of the control plane around it: a repo-owned Compose file, an example `vault.hcl`, path-scoped ACL policies, and a host-driven script that pushes changes into Coolify by SSHing into the host and executing PHP inside the Coolify container.

I also inspected the CoinVault and hair-booking materials because the migration design depends on how apps actually consume secrets today. That pass showed that the current secret paths are already clean and worth preserving, while the current AppRole bootstrap pattern is mainly a concession to the fact that the apps run outside Kubernetes today.

### Prompt Context

**User prompt (verbatim):** (see Step 1)

**Assistant interpretation:** Investigate the current Vault, app integration, and Terraform-side platform setup before recommending a K3s target architecture.

**Inferred user intent:** Avoid a generic “Vault on Kubernetes” answer by grounding the recommendation in the actual live secret paths, auth model, and deployment scripts already in use.

### What I did
- Inspected Vault service docs and definitions:
  - `/home/manuel/code/wesen/terraform/coolify/services/vault/README.md`
  - `/home/manuel/code/wesen/terraform/coolify/services/vault/docker-compose.yaml`
  - `/home/manuel/code/wesen/terraform/coolify/services/vault/vault.hcl.awskms.example`
- Inspected policies and helper scripts:
  - `app-hair-booking-prod.hcl`
  - `app-coinvault-prod.hcl`
  - `generate_hair_booking_approle_material.sh`
  - `seed_hair_booking_ses_secret.sh`
  - `seed_coinvault_runtime_and_pinocchio_secrets.sh`
  - `provision_vault_via_coolify_host.sh`
- Inspected existing Terraform ticket docs for:
  - Vault on Coolify planning
  - deployment postmortem
  - auth hardening
  - backups
  - audit logging
- Inspected CoinVault deployment and bootstrap docs:
  - `docs/deployments/coinvault-coolify.md`
  - `docs/deployments/coinvault-coolify.env.example`
  - `internal/bootstrap/bootstrap.go`
  - `docker/entrypoint.sh`
- Inspected the repo-local Terraform `.envrc`.

### Why
- The migration target should preserve the parts that are already good, such as path layout and policy boundaries.
- The design should also deliberately replace the parts that are currently awkward, like host-driven Coolify mutation and AppRole as the default app auth path.

### What worked
- The current system is much less chaotic than “semi-manual” suggests at first glance.
- Important platform facts were already documented in the Terraform tickets.
- The app secret taxonomy is strong enough to reuse directly in the K3s design.

### What didn't work
- One attempted path open for an older Terraform ticket analysis used the wrong directory name and failed with:

```text
sed: can't read /home/manuel/code/wesen/terraform/ttmp/2026/03/25/TF-008-VAULT-AUTH-HARDENING--implement-vault-auth-hardening-with-keycloak-policies-and-a-go-integration-example/analysis/01-vault-auth-hardening-plan-with-keycloak-policies-and-a-go-integration-example.md: No such file or directory
```

- I corrected it by listing the exact ticket directory and reopening the document using the actual `...keycloak-and-a-go-end-to-end-example` path.

### What I learned
- The current Vault path layout is already good and should survive the migration.
- CoinVault’s current Vault integration is mature enough to use as the migration test case later, but still shaped around an off-cluster AppRole bootstrap.
- The Coolify Vault operational model is powerful but too coupled to the old platform internals to be a good long-term destination.
- The Terraform `.envrc` currently exports live provider and object-storage credentials directly. That is a real operator-pattern smell and should not be copied into the K3s design.

### What was tricky to build
- The tricky part was separating “current behavior that should be preserved” from “current mechanism that should be retired.” For example, `kv/apps/coinvault/prod/runtime` is a good path contract. AppRole bootstrap through env vars is not the long-term cluster-native mechanism. The research had to tease those apart carefully so the later design would not either overpreserve the old system or dismiss the useful parts.

### What warrants a second pair of eyes
- Whether the app secret layout should remain exactly as-is or be expanded with a more formal `infra/k3s` subtree before implementation begins.

### What should be done in the future
- Add an implementation ticket for “K3s Vault path and policy bootstrap” once this design is approved.
- Add a separate ticket later for cleaning up repo-local operator credential handling.

### Code review instructions
- Review these first:
  - [/home/manuel/code/wesen/terraform/coolify/services/vault/docker-compose.yaml](/home/manuel/code/wesen/terraform/coolify/services/vault/docker-compose.yaml)
  - [/home/manuel/code/wesen/terraform/coolify/services/vault/vault.hcl.awskms.example](/home/manuel/code/wesen/terraform/coolify/services/vault/vault.hcl.awskms.example)
  - [/home/manuel/code/wesen/terraform/coolify/services/vault/policies/app-coinvault-prod.hcl](/home/manuel/code/wesen/terraform/coolify/services/vault/policies/app-coinvault-prod.hcl)
  - [/home/manuel/code/gec/2026-03-16--gec-rag/internal/bootstrap/bootstrap.go](/home/manuel/code/gec/2026-03-16--gec-rag/internal/bootstrap/bootstrap.go)
- Confirm that the design doc’s “current-state” section is consistent with these files before evaluating the recommendations.

### Technical details
- Commands run included:
  - `rg --files /home/manuel/code/wesen/terraform`
  - `rg -n "vault|coolify|argocd|k3s|external-secrets|sealed-secrets|sops|doppler|1password|postgres|redis|supabase" ...`
  - `nl -ba /home/manuel/code/wesen/terraform/coolify/services/vault/docker-compose.yaml | sed -n '1,220p'`
  - `nl -ba /home/manuel/code/wesen/terraform/coolify/services/vault/vault.hcl.awskms.example | sed -n '1,220p'`
  - `nl -ba /home/manuel/code/wesen/terraform/coolify/services/vault/scripts/provision_vault_via_coolify_host.sh | sed -n '1,280p'`
  - `nl -ba /home/manuel/code/gec/2026-03-16--gec-rag/internal/bootstrap/bootstrap.go | sed -n '1,280p'`

## Step 3: Inspect the live K3s cluster and the current GitOps boundary

After understanding the old control plane, I switched to the new one. The key question here was not “does the cluster exist,” because that was already known from the previous deployment ticket. The real question was whether the cluster is mature enough to host Vault and whether the current repo structure can support another platform application without reintroducing Terraform drift.

This inspection confirmed that the cluster is in the right shape for the first platform move. K3s, Traefik, cert-manager, Argo CD, and the local-path provisioner are all already running; the current application is `Synced Healthy`; and the node has enough free memory and disk to absorb a single-node Vault plus a lightweight controller such as the Vault Secrets Operator.

### Prompt Context

**User prompt (verbatim):** (see Step 1)

**Assistant interpretation:** Inspect the current K3s and Argo CD environment and figure out how Vault should fit into it without recreating the Hetzner server or fighting the current GitOps boundary.

**Inferred user intent:** Design Vault for the platform that actually exists now, not for a hypothetical cluster.

### What I did
- Inspected:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/cloud-init.yaml.tftpl`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/demo-stack.yaml`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/demo-stack/kustomization.yaml`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/hetzner-k3s-server-setup.md`
- Verified the current kubeconfig and server-side K3s config.
- Queried the live cluster with explicit `KUBECONFIG=...`:
  - `kubectl get nodes -o wide`
  - `kubectl get storageclass,ingressclass,ns`
  - `kubectl get applications -n argocd -o wide`
  - `kubectl get pods -A -o wide`
  - `kubectl top node`
  - `kubectl top pods -A`
- Queried the Hetzner node directly over SSH:
  - `hostname`
  - `free -h`
  - `df -h / /var/lib/rancher/k3s /var/lib/docker`

### Why
- Vault should be designed around the real storage class, ingress class, and node capacity.
- The migration plan must respect the current rule that long-term cluster state belongs in GitOps, not in Terraform `user_data`.

### What worked
- The K3s node is healthy and lightly loaded.
- Argo CD is already functioning as the long-term controller.
- The cluster has the minimum add-ons Vault needs: ingress, TLS automation, and persistent volume provisioning.

### What didn't work
- My first `kubectl` calls failed because the shell was using a different kube context pointing to `https://kubernetes.docker.internal:6443`:

```text
The connection to the server kubernetes.docker.internal:6443 was refused - did you specify the right host or port?
```

- The fix was to force the intended kubeconfig path per command:

```bash
KUBECONFIG=/home/manuel/code/wesen/2026-03-27--hetzner-k3s/kubeconfig-91.98.46.169.yaml kubectl ...
```

### What I learned
- The cluster is single-node but not resource-starved.
- The current repo already has the right GitOps boundary: platform/app state should be added through Argo applications, not pushed back into `cloud-init`.
- The existing `*.yolo.scapegoat.dev` operator-hostname pattern suggests a clean way to stand up Vault in parallel under a new hostname first.

### What was tricky to build
- The main sharp edge here was context leakage from the shell environment. The repo-local `.envrc` was no longer enough because another kube context had taken precedence. If I had not validated the actual kubeconfig content and forced `KUBECONFIG` explicitly, the investigation could easily have drawn wrong conclusions about cluster reachability.

### What warrants a second pair of eyes
- Whether the cluster should gain an additional platform-app root in Argo CD before Vault is added, or whether standalone `Application` manifests are sufficient for the first migration pass.

### What should be done in the future
- When implementing the Vault move, make the repo-local `.envrc` more defensive so `kubectl` uses the correct file by default in a fresh shell.

### Code review instructions
- Start with:
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/cloud-init.yaml.tftpl](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/cloud-init.yaml.tftpl)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/demo-stack.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/demo-stack.yaml)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/demo-stack/kustomization.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/demo-stack/kustomization.yaml)
- Validate that the design’s recommendation to keep Vault in GitOps rather than Terraform bootstrap follows from the current repo architecture.

### Technical details
- Commands run:
  - `sed -n '1,220p' kubeconfig-91.98.46.169.yaml`
  - `ssh -o BatchMode=yes root@91.98.46.169 'hostname && systemctl is-active k3s && sudo cat /etc/rancher/k3s/k3s.yaml | sed -n "1,80p"'`
  - `KUBECONFIG=... kubectl get nodes -o wide`
  - `KUBECONFIG=... kubectl get storageclass,ingressclass,ns`
  - `KUBECONFIG=... kubectl get applications -n argocd -o wide`
  - `KUBECONFIG=... kubectl top node`
  - `ssh -o BatchMode=yes root@91.98.46.169 'hostname; nproc; free -h; df -h / /var/lib/rancher/k3s /var/lib/docker || true'`

## Step 4: Synthesize the target architecture and write the migration guidance

Once the current-state evidence was gathered, the remaining work became architectural synthesis rather than more discovery. The key design decision was to avoid false purity. The “perfect” answer would be to move everything to direct Vault clients immediately, eliminate all bootstrap exceptions, and maybe redesign the entire app-of-apps layout at once. That would be the wrong recommendation for this environment. The right answer is the one that matches the current K3s cluster, preserves working secret paths and OIDC concepts, and lowers the cost of app migration instead of raising it.

That reasoning led to the main recommendation: deploy Vault itself through Argo CD using the official Helm chart, keep AWS KMS auto-unseal, use Kubernetes auth for in-cluster workloads, and adopt the Vault Secrets Operator as the default migration bridge for app secrets. This preserves a clear long-term control plane while still meeting the apps where they are today.

### Prompt Context

**User prompt (verbatim):** (see Step 1)

**Assistant interpretation:** Turn the research into a detailed intern-friendly design and implementation guide, then package it with the ticket diary and a concise playbook.

**Inferred user intent:** Leave behind a document bundle that another engineer could use both to understand the problem space and to execute the first real migration tickets later.

### What I did
- Wrote the primary design doc:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/design-doc/01-vault-on-k3s-and-gitops-migration-design.md`
- Added a playbook doc for the operational sequence.
- Updated the ticket index, tasks, and changelog to reflect the research and deliverables.
- Included:
  - current-state architecture
  - gap analysis
  - target system diagrams
  - phased implementation plan
  - API/resource references
  - migration guidance for hair-booking and CoinVault

### Why
- The user explicitly asked for intern-grade clarity and long-form detail.
- A design doc alone can become too abstract; a playbook makes the later implementation path much easier to follow.

### What worked
- The evidence gathered earlier was enough to support concrete recommendations rather than generic best practices.
- The current app secret contracts mapped cleanly onto the proposed VSO-based migration model.

### What didn't work
- A shell globbing issue briefly broke one Vault health check attempt because `?standbyok=true` was not quoted:

```text
zsh:1: no matches found: https://vault.app.scapegoat.dev/v1/sys/health?standbyok=true
```

- Re-running the command with quotes fixed it:

```bash
curl -sS 'https://vault.app.scapegoat.dev/v1/sys/health?standbyok=true'
```

### What I learned
- The cleanest design is not “all apps must become Vault clients.” The cleanest design here is “Vault becomes a K3s platform service, and apps migrate onto cluster-native secret delivery first.”
- The existing DNS and operator-hostname pattern makes a parallel hostname cutover strategy much safer than attempting a same-name replacement immediately.

### What was tricky to build
- The hardest design tradeoff was choosing the default application consumption model. Pure direct Vault access is elegant, but it would increase migration cost for apps like CoinVault that already have a specific bootstrap shape and for simpler consumers like hair-booking that mostly want configuration values. VSO is less pure, but it is the better migration default because it makes the movement to K3s easier while still keeping Vault as the source of truth.

### What warrants a second pair of eyes
- Whether you want to standardize on VSO long-term, or only as a migration bridge before some apps move to Injector/direct Vault integration.
- Whether the first migrated consumer after Vault should be hair-booking for lower risk or CoinVault because it already has the richest Vault contract.

### What should be done in the future
- Run `docmgr doctor`, relate all key files, and upload the bundle to reMarkable.
- After review, create implementation tickets in the order recommended by the design doc.

### Code review instructions
- Read in this order:
  1. [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/design-doc/01-vault-on-k3s-and-gitops-migration-design.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/design-doc/01-vault-on-k3s-and-gitops-migration-design.md)
  2. [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/playbook/01-vault-on-k3s-migration-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/playbook/01-vault-on-k3s-migration-playbook.md)
  3. this diary
- Validate that every major recommendation can be traced back to either:
  - a local file inspected during the research pass, or
  - an explicit official Vault Kubernetes reference cited in the design doc.

### Technical details
- Additional commands run:
  - `curl -I -sS https://vault.app.scapegoat.dev/ui/ | sed -n '1,20p'`
  - `curl -sS 'https://vault.app.scapegoat.dev/v1/sys/health?standbyok=true'`

## Step 5: Validate the ticket and publish the document bundle

After the content was written, I switched into ticket hygiene and delivery mode. This matters because the user did not ask for notes that only exist in the local working tree. They asked for a reusable ticket bundle with a diary trail, a design deliverable, and a reMarkable upload. That means the content needed to be validated with `docmgr`, the file relationships needed to be clean, the vocabulary needed to be updated, and the upload needed to be verified rather than assumed.

This step completed that packaging work. I related the key files to the design, diary, and playbook; fixed the doc vocabulary warnings by adding `vault`, `k3s`, `argocd`, and `migration` to the ticket vocabulary; trimmed the index-level related files to avoid broken cross-repo path normalization; reran `docmgr doctor` to a clean pass; then uploaded the bundle to reMarkable under `/ai/2026/03/27/HK3S-0002`.

### Prompt Context

**User prompt (verbatim):** (see Step 1)

**Assistant interpretation:** Finish the ticket like a real deliverable, including validation and external publication.

**Inferred user intent:** Make the design easy to revisit and review outside the terminal session.

### What I did
- Ran `docmgr doc relate` for the design doc, diary, playbook, and ticket index.
- Added new topic vocabulary entries:
  - `vault`
  - `k3s`
  - `argocd`
  - `migration`
- Ran `docmgr doctor --ticket HK3S-0002 --stale-after 30` until it passed cleanly.
- Ran:
  - `remarquee status`
  - `remarquee cloud account --non-interactive`
  - `remarquee upload bundle --dry-run ...`
  - `remarquee upload bundle ...`
  - `remarquee cloud ls /ai/2026/03/27/HK3S-0002 --long --non-interactive`

### Why
- Validation is part of the deliverable, not optional polish.
- A successful upload with a verified remote listing is much more trustworthy than saying “it should be there.”

### What worked
- `docmgr doctor` passed after the vocabulary additions and index cleanup.
- The bundle dry-run worked on the first attempt.
- The real upload succeeded and the remote listing confirmed the document exists.

### What didn't work
- The first `docmgr doctor` run surfaced:
  - unknown topic vocabulary,
  - and malformed cross-repo `RelatedFiles` entries on the ticket index.
- I resolved those by adding vocabulary entries and removing the cross-repo links from the index while leaving the detailed subdocument relations intact.
- My first `remarquee cloud ls` verification was too early, before the upload process had completed, and returned:

```text
Error: no matches for 'HK3S-0002'
```

- Waiting for the upload command to finish and then rerunning the listing fixed it.

### What I learned
- The index document should prefer repo-local related files only. Cross-repo evidence belongs on the focused subdocuments where `docmgr` can tolerate more complexity.
- The bundle upload flow is reliable as long as verification happens after the upload process exits.

### What was tricky to build
- The sharp edge here was `docmgr` path normalization for cross-repo related files on the index. The detailed docs can still reference external repository files directly in their content, but the ticket index frontmatter is better kept narrower so `doctor` stays clean. The fix was not to delete evidence, but to move the burden of cross-repo references away from the top-level index and onto the design/diary documents where that detail is actually needed.

### What warrants a second pair of eyes
- Whether future cross-repo tickets should avoid index-level external file relations entirely as a house rule.

### What should be done in the future
- Commit and push this ticket state as the clean checkpoint for the research phase.
- Open the first implementation ticket for the actual Vault-on-K3s deployment when ready.

### Code review instructions
- Validate:
  - `docmgr doctor --ticket HK3S-0002 --stale-after 30`
  - `remarquee cloud ls /ai/2026/03/27/HK3S-0002 --long --non-interactive`
- Review:
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/tasks.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/tasks.md)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/vocabulary.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/vocabulary.yaml)

### Technical details
- Verified upload target:
  - `/ai/2026/03/27/HK3S-0002`
- Verified remote entry:
  - `HK3S-0002 Vault on K3s migration design`

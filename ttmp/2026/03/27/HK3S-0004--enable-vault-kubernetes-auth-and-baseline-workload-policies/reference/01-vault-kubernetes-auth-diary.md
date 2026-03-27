---
Title: Vault Kubernetes auth implementation diary
Ticket: HK3S-0004
Status: active
Topics:
    - vault
    - k3s
    - kubernetes
    - gitops
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: gitops/applications/vault-kubernetes-auth.yaml
      Note: Repo-managed Argo CD application for the smoke namespace/service account (commit 7904417)
    - Path: scripts/bootstrap-vault-kubernetes-auth.sh
      Note: Operator bootstrap helper for auth backend
    - Path: scripts/validate-vault-kubernetes-auth.sh
      Note: Validation helper for service-account login and least-privilege checks (commit 7904417)
    - Path: vault/policies/kubernetes/vault-auth-smoke.hcl
      Note: Smoke workload policy that anchors the initial least-privilege model (commit 7904417)
ExternalSources: []
Summary: Chronological diary for enabling Vault Kubernetes auth and baseline workload policies on the K3s cluster.
LastUpdated: 2026-03-27T14:02:00-04:00
WhatFor: Use this to review the exact implementation trail, including mistakes, validation steps, and follow-up decisions.
WhenToUse: Read this when continuing or reviewing the Kubernetes-auth implementation ticket.
---


# Vault Kubernetes auth implementation diary

## Goal

Capture the implementation work for enabling Vault Kubernetes auth on the K3s cluster, including the Kubernetes RBAC setup, Vault auth backend configuration, baseline policies and roles, and the end-to-end workload validation path.

## Step 1: Open the follow-up ticket set and ground the first ticket in real consumers

The first thing I did in this ticket was make the follow-up work concrete instead of leaving it as a bullet list in `HK3S-0003`. I created four new tickets: Kubernetes auth, OIDC operator login, Vault Secrets Operator, and first app recreation on K3s. This ticket is the first of that set because it is the identity foundation every later machine-facing step depends on. Before writing tasks, I checked the existing consumer context again, especially CoinVault’s Coolify deployment docs and the current Terraform-side Vault auth hardening work, so the plan would match the real path and naming conventions already in use.

That re-check was important because “enable Kubernetes auth” can easily turn into an abstract infrastructure ticket if it is not tied back to real app contracts. CoinVault already documents its current Vault secret paths under `kv/apps/coinvault/prod/...`, and the Terraform repo already documents the human OIDC operator path and current policy style. Those two anchors are enough to define the first K3s machine-auth slice without guessing what later app tickets will need.

### Prompt Context

**User prompt (verbatim):** "cool, yes create a new ticket for that, and also new tickets for the other tickets you recommended. For each, add a detailed analysis/implementation plan and detailed tasks. 

Then, start working on the first one, task by task, committing at appropriate intervals, and updating your diary as you go"

**Assistant interpretation:** Create the next four implementation tickets, document each one with a concrete plan and task breakdown, then begin executing the Kubernetes-auth ticket immediately with diary updates and focused commits.

**Inferred user intent:** Turn the post-Vault-deployment roadmap into an actual executable sequence and start moving the next dependency layer, not just discussing it.

### What I did
- Created tickets:
  - `HK3S-0004` Kubernetes auth and baseline roles
  - `HK3S-0005` Keycloak OIDC operator login on K3s Vault
  - `HK3S-0006` Vault Secrets Operator on K3s
  - `HK3S-0007` first app recreation using Vault-managed secrets
- Re-read the finished Vault deployment ticket `HK3S-0003`.
- Inspected the CoinVault deployment docs and existing Terraform-side Vault auth/OIDC playbooks.
- Wrote the first detailed implementation plan and task breakdown for this ticket.

### Why
- The next steps should be separate tickets because they each have their own risks, validations, and rollback boundaries.
- Kubernetes auth needs to be designed with the actual app naming and secret path conventions in mind.

### What worked
- The new ticket workspaces were created cleanly.
- Existing docs gave enough context to define a concrete path for Kubernetes auth.

### What didn't work
- I initially looked for `.envrc` files directly in the target app roots and did not find them there. That was informative, but it meant the better source of truth was the actual deployment docs and runtime secret contracts rather than a root-level env file.

### What I learned
- CoinVault is the clearest first downstream consumer because its current secret paths and hosted runtime contract are already documented in detail.
- The K3s machine-auth path should align with `kv/apps/<app>/<env>/...` from the start.

### What was tricky to build
- The subtle part here was avoiding a “ticket factory” outcome where four new tickets exist but still contain vague text. The plan needed to be specific enough that a later implementer could actually start from the docs without rereading the entire repo.

### What warrants a second pair of eyes
- Whether `coinvault-prod` and `hair-booking-prod` are the right first baseline roles to create ahead of workload migration.

### What should be done in the future
- Start the repo-managed scaffold for Kubernetes auth next.

### Code review instructions
- Review:
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0004--enable-vault-kubernetes-auth-and-baseline-workload-policies/tasks.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0004--enable-vault-kubernetes-auth-and-baseline-workload-policies/tasks.md)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0004--enable-vault-kubernetes-auth-and-baseline-workload-policies/playbook/01-vault-kubernetes-auth-implementation-plan.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0004--enable-vault-kubernetes-auth-and-baseline-workload-policies/playbook/01-vault-kubernetes-auth-implementation-plan.md)
- Confirm the role/path conventions are a sensible basis for later app tickets.

### Technical details
- Internal docs inspected:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0003--implement-vault-on-k3s-via-argo-cd/index.md`
  - `/home/manuel/code/gec/2026-03-16--gec-rag/docs/deployments/coinvault-coolify.md`
  - `/home/manuel/code/gec/2026-03-16--gec-rag/docs/deployments/coinvault-hosted-operations.md`
  - `/home/manuel/code/wesen/terraform/ttmp/2026/03/25/TF-008-VAULT-AUTH-HARDENING--implement-vault-auth-hardening-with-keycloak-and-a-go-end-to-end-example/playbooks/01-vault-oidc-operator-playbook.md`

## Step 2: Add the Kubernetes-auth scaffold and reconcile it against the live Vault chart behavior

This step turned the first ticket from planning into executable repo state. I added reviewable Vault policy files, role definitions, an operator bootstrap script for Vault-side auth/config state, a validation script for the service-account login flow, and a small Argo CD application for the smoke-test namespace and service account. That provides a full repo-side control surface before touching the live Vault state.

The most important thing I learned during this step was that the Vault Helm chart already creates the `system:auth-delegator` ClusterRoleBinding for the Vault service account. That matters because my initial plan assumed I would need to create that RBAC myself. Instead of duplicating it and risking overlapping ownership, I adjusted the repo scaffold so the new GitOps package only manages the smoke namespace/service account while the chart remains authoritative for the reviewer binding.

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Start the first real implementation slice of the Kubernetes-auth ticket, commit it cleanly, and keep the diary current.

**Inferred user intent:** Build the actual repo and operator assets that will be used for live Vault configuration, not just plan them.

**Commit (code):** 7904417 — "feat: add vault kubernetes auth scaffold"

### What I did
- Inspected live state:
  - `vault auth list` showed only `token/`
  - `vault secrets list` showed only `cubbyhole/`, `identity/`, and `sys/`
  - `vault policy list` showed only `default` and `root`
  - the cluster already contained `ClusterRoleBinding/vault-server-binding` to `system:auth-delegator`
- Added policy files:
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/vault-auth-smoke.hcl](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/vault-auth-smoke.hcl)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/coinvault-prod.hcl](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/coinvault-prod.hcl)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/hair-booking-prod.hcl](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/hair-booking-prod.hcl)
- Added role definitions:
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/vault-auth-smoke.json](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/vault-auth-smoke.json)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/coinvault-prod.json](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/coinvault-prod.json)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/hair-booking-prod.json](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/hair-booking-prod.json)
- Added operator scripts:
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-kubernetes-auth.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-kubernetes-auth.sh)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-vault-kubernetes-auth.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-vault-kubernetes-auth.sh)
- Added the smoke namespace/service account GitOps app:
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-kubernetes-auth.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-kubernetes-auth.yaml)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-kubernetes-auth/kustomization.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/vault-kubernetes-auth/kustomization.yaml)
- Updated [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/README.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/README.md) so the new workflow is discoverable.

### Why
- Vault-side configuration should be based on reviewable files rather than one-off shell history.
- The smoke namespace/service account should live in GitOps state even if the Vault-side writes still require an operator script.
- Avoiding duplicate ownership of the reviewer ClusterRoleBinding is cleaner than creating another manifest just because the original plan assumed it was missing.

### What worked
- The scripts validated with `bash -n`.
- The kustomize package rendered cleanly.
- The Argo CD application manifest parsed cleanly as YAML.
- The live state inspection made the missing and already-present platform pieces explicit.

### What didn't work
- My initial plan assumed the reviewer ClusterRoleBinding was not present. That was wrong. The live cluster inspection showed the Helm chart already created:

```text
vault-server-binding -> ClusterRole/system:auth-delegator
```

- That was a good correction, not a blocker.

### What I learned
- The chart already owns the reviewer RBAC, so the repo should not try to own it again.
- The new Vault instance is still almost empty from an auth/secrets point of view, which makes this ticket a true bootstrap step.
- The `kv/apps/<app>/<env>/...` convention is easy to encode early through both policy files and role naming.

### What was tricky to build
- The tricky part was deciding which layer should own what. It would have been easy to put everything into one script, but that would weaken the GitOps story. It would also have been easy to over-GitOps the problem and pretend Argo CD can own Vault auth state directly. The compromise here is deliberate: Git owns the policy/role source files and the Kubernetes smoke resources, while the operator script writes Vault’s internal auth state from those repo files.

### What warrants a second pair of eyes
- Whether the baseline role names `coinvault-prod` and `hair-booking-prod` should stay fixed now or wait until the first app ticket finalizes namespace/service-account names.

### What should be done in the future
- Apply the smoke namespace/service account through Argo CD next.
- Run the bootstrap script against the live Vault instance.
- Validate login, read, and deny behavior with a real service-account token.

### Code review instructions
- Review:
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-kubernetes-auth.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-kubernetes-auth.sh)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-vault-kubernetes-auth.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-vault-kubernetes-auth.sh)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-kubernetes-auth.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-kubernetes-auth.yaml)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/vault-auth-smoke.hcl](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/vault-auth-smoke.hcl)
- Validate locally with:
  - `bash -n scripts/bootstrap-vault-kubernetes-auth.sh`
  - `bash -n scripts/validate-vault-kubernetes-auth.sh`
  - `kubectl kustomize gitops/kustomize/vault-kubernetes-auth`

### Technical details
- Commands run:
  - `kubectl get clusterrolebinding vault-server-binding -o yaml`
  - `kubectl -n vault exec vault-0 -- env VAULT_TOKEN=... vault auth list -format=json`
  - `kubectl -n vault exec vault-0 -- env VAULT_TOKEN=... vault secrets list -format=json`
  - `kubectl -n vault exec vault-0 -- env VAULT_TOKEN=... vault policy list`
  - `bash -n scripts/bootstrap-vault-kubernetes-auth.sh`
  - `bash -n scripts/validate-vault-kubernetes-auth.sh`
  - `kubectl kustomize gitops/kustomize/vault-kubernetes-auth`

## Step 3: Apply the smoke app through Argo and bootstrap the live Vault auth state

After the scaffold commit was in place, I moved to the live cluster. The smoke namespace/service account went through Argo CD first so the Kubernetes-side identity existed before the login validation. Then I used the Vault root token from the 1Password init note to run the bootstrap script against `vault.yolo.scapegoat.dev`. That script enabled `kv/`, enabled and configured `auth/kubernetes`, wrote the three policies, wrote the three roles, and seeded both the allowed smoke secret path and a second out-of-scope path for deny testing.

The only unexpected moment in this step was a GitOps sequencing issue: I created the Argo CD application before pushing the new repo commits, so Argo initially showed `sync=Unknown` because the referenced path did not exist in the remote Git revision yet. Pushing `main` and forcing a refresh fixed that immediately. The Vault bootstrap itself succeeded on the first try. Vault emitted warnings that the roles did not configure JWT `audience`, but those were warnings rather than failures and the current design intentionally accepts that because workload audience standardization has not been introduced yet.

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Continue from the repo scaffold into the real cluster and Vault mutation steps, with the same careful diary trail.

**Inferred user intent:** Make the platform feature actually live and working, not just present in Git.

### What I did
- Applied [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-kubernetes-auth.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/vault-kubernetes-auth.yaml) to Argo CD.
- Pushed the local commits so Argo could fetch the new path from Git.
- Forced an Argo refresh and confirmed:
  - app `vault-kubernetes-auth` became `Synced Healthy`
  - namespace `vault-auth-smoke` existed
  - service account `vault-auth-smoke` existed
- Ran [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-kubernetes-auth.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-kubernetes-auth.sh) against the live Vault instance using the root token from the 1Password init bundle.
- Verified post-bootstrap live state:
  - auth mounts: `kubernetes/`, `token/`
  - secrets engines: `kv/`, `cubbyhole/`, `identity/`, `sys/`
  - role `vault-auth-smoke` bound to namespace/service-account `vault-auth-smoke/vault-auth-smoke`

### Why
- The smoke namespace/service account had to exist before validating Kubernetes-auth login.
- The Git push was required because Argo CD reconciles from the remote repository, not from local unpushed commits.
- The bootstrap script is the canonical path for turning the repo policy/role definitions into live Vault state.

### What worked
- Argo CD reconciled the smoke app successfully once the repo state was pushed.
- The Vault bootstrap script completed successfully.
- `auth/kubernetes` and `kv/` now exist on the live K3s Vault.
- The baseline roles and policies were written as intended.

### What didn't work
- The first Argo poll showed `sync=Unknown` because I had created the `Application` before pushing the referenced Git path upstream.
- Vault returned warnings on role writes:

```text
Role <name> does not have an audience configured.
```

- Those were warnings only, not failures.

### What I learned
- The GitOps dependency here is strict: Argo will not magically see local-only commits.
- The current bootstrap path is sufficient to bring up live Kubernetes auth in one pass.
- Leaving role `audience` unset is viable right now, but it is a conscious compatibility tradeoff, not an accidental omission.

### What was tricky to build
- The tricky part was sequencing across three systems at once: Git, Argo CD, and Vault. The Kubernetes objects needed to be present before validation. Argo needed the repo state pushed before it could materialize those objects. Vault needed the smoke identity to exist before the end-to-end login check was meaningful. Missing one of those ordering constraints produces confusing but valid-looking partial states.

### What warrants a second pair of eyes
- Whether the cluster should later standardize a service-account token audience and tighten the roles accordingly.

### What should be done in the future
- Run the explicit login/read/deny validation next.

### Code review instructions
- Validate live state with:
  - `kubectl -n argocd get application vault-kubernetes-auth`
  - `kubectl get ns vault-auth-smoke`
  - `kubectl -n vault-auth-smoke get sa vault-auth-smoke`
  - `vault auth list`
  - `vault secrets list`
  - `vault read auth/kubernetes/role/vault-auth-smoke`

### Technical details
- Commands run:
  - `kubectl apply -f gitops/applications/vault-kubernetes-auth.yaml`
  - `git push origin HEAD`
  - `kubectl -n argocd annotate application vault-kubernetes-auth argocd.argoproj.io/refresh=hard --overwrite`
  - `VAULT_ADDR=https://vault.yolo.scapegoat.dev VAULT_TOKEN=... ./scripts/bootstrap-vault-kubernetes-auth.sh`
  - `vault auth list -format=json | jq 'keys'`
  - `vault secrets list -format=json | jq 'keys'`
  - `vault read -format=json auth/kubernetes/role/vault-auth-smoke`

## Step 4: Validate a real service-account login and prove least-privilege

The final operational check in this ticket was the real workload-auth proof. I used the smoke service account in namespace `vault-auth-smoke` to mint a JWT with `kubectl create token`, then used the validation script to log in through `auth/kubernetes/login`. The returned Vault token successfully read the intended smoke secret under `kv/apps/vault-auth-smoke/dev/demo` and failed to read the out-of-scope secret under `kv/apps/vault-auth-other/dev/demo`. That is the exact behavior this ticket needed to establish.

This matters because it proves both halves of the feature: authentication and authorization. A successful login by itself would not be enough if the resulting token was too broad. A denied read by itself would not be enough if the token could not authenticate. The validation script now exercises both and leaves behind a repeatable operator command path.

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Finish the feature slice with a real end-to-end proof instead of only configuration writes.

**Inferred user intent:** Leave this ticket in a state where later app tickets can trust the machine-auth foundation.

### What I did
- Ran [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-vault-kubernetes-auth.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-vault-kubernetes-auth.sh) against the live cluster and Vault instance.
- Confirmed the validation path:
  - minted JWT for `vault-auth-smoke/vault-auth-smoke`
  - logged in to `auth/kubernetes/login`
  - read `kv/apps/vault-auth-smoke/dev/demo`
  - failed to read `kv/apps/vault-auth-other/dev/demo`
- Collected the final live-state evidence for the ticket:
  - `vault auth list`
  - `vault secrets list`
  - `vault read auth/kubernetes/role/vault-auth-smoke`
  - `kubectl -n argocd get application vault-kubernetes-auth`

### Why
- This is the minimal end-to-end proof that later platform layers depend on.
- It validates both identity binding and least-privilege enforcement.

### What worked
- The validation script passed cleanly.
- The smoke role now proves exactly the intended permission shape.
- Argo CD reported the smoke Kubernetes resources as `Synced Healthy`.

### What didn't work
- The first validation attempt failed because I had launched it before the bootstrap finished writing the role:

```text
Code: 400. Errors:

* invalid role name "vault-auth-smoke"
```

- Rerunning after the bootstrap completed resolved that immediately.

### What I learned
- The validation script is sensitive to ordering, which is good because it catches incomplete bootstrap state quickly.
- The current platform state is now strong enough to support the next tickets instead of just theorizing about them.

### What was tricky to build
- The main sharp edge was avoiding a false negative from parallel execution. I initially launched validation too early, which produced a legitimate but transient “invalid role name” error. That confirmed the validation script was working as intended, but it also reinforced that bootstrap completion has to be treated as a prerequisite, not a background side-effect.

### What warrants a second pair of eyes
- Whether we should eventually add a second validation path from inside a running pod rather than relying on `kubectl create token` from the operator workstation.

### What should be done in the future
- Open the OIDC ticket next so humans have a normal operator login path too.
- Then move to Vault Secrets Operator and first app recreation.

### Code review instructions
- Re-run:
  - `export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml`
  - `export VAULT_ADDR=https://vault.yolo.scapegoat.dev`
  - `export VAULT_TOKEN=<root-token-or-break-glass-token>`
  - `./scripts/validate-vault-kubernetes-auth.sh`
- Confirm the output reports the allowed and denied paths correctly.

### Technical details
- Commands run:
  - `VAULT_ADDR=https://vault.yolo.scapegoat.dev VAULT_TOKEN=... ./scripts/validate-vault-kubernetes-auth.sh`
  - `kubectl -n argocd get application vault-kubernetes-auth -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{"\n"}'`
  - `vault auth list -format=json | jq 'keys'`
  - `vault secrets list -format=json | jq 'keys'`
  - `vault read -format=json auth/kubernetes/role/vault-auth-smoke | jq '.data | {names:.bound_service_account_names,namespaces:.bound_service_account_namespaces,policies:.token_policies}'`

## Step 5: Close out the ticket and normalize the doc metadata

After the live validation passed, I did one more documentation pass instead of treating the technical success as the end. I reran `docmgr doctor` for the ticket and found a metadata warning: the docs were tagged with `security`, but that value is not part of this repository's `Topics` vocabulary. I removed that unsupported topic from the ticket docs, reran the doctor check, and marked the remaining handoff task complete.

That closeout matters because these ticket docs are supposed to become long-lived operator references. A technically correct ticket that still fails repository conventions is harder to search, validate, and hand off. Fixing that here keeps the documentation set consistent before the next follow-up tickets build on it.

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Finish the ticket completely, including its documentation hygiene and handoff quality.

**Inferred user intent:** Leave behind a clean, validated ticket set rather than stopping at "the cluster works."

### What I did
- Ran `git diff --check`.
- Ran `docmgr doctor --ticket HK3S-0004 --stale-after 30`.
- Removed the unsupported `security` topic from the ticket docs.
- Marked the doctor-validation task complete in [tasks.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0004--enable-vault-kubernetes-auth-and-baseline-workload-policies/tasks.md).
- Updated the ticket index, changelog, and implementation plan with the final completion state and next-ticket references.

### Why
- Ticket metadata should validate cleanly before the ticket is treated as a stable operator artifact.
- The next tickets depend on this one, so the completion signal needs to be explicit and reviewable.

### What worked
- `git diff --check` passed.
- The only `docmgr doctor` issue was a straightforward vocabulary mismatch.
- The ticket is now consistent with the repository's topic taxonomy.

### What didn't work
- I initially treated the first `docmgr doctor` pass as "good enough" because it returned only a warning, but for a long-lived ticket set that is not a strong enough finish. The warning was easy to fix and worth fixing.

### What I learned
- The repository's doc vocabulary is opinionated enough that even sensible generic tags like `security` need to be normalized to the existing topic set.
- The best time to fix that is immediately during ticket closeout, not later when the docs are already being referenced.

### What was tricky to build
- Nothing here was technically hard. The subtle part was resisting the temptation to stop after the live validation instead of doing the metadata and handoff cleanup while all of the context was still fresh.

### What warrants a second pair of eyes
- Whether the current topic set is sufficient long-term for the upcoming Vault operator/auth tickets, or whether the shared vocabulary should be expanded deliberately in a future cleanup.

### What should be done in the future
- Move directly to `HK3S-0005`, `HK3S-0006`, and `HK3S-0007` as planned.
- Reuse the same closeout discipline for those tickets so the ticket set stays coherent.

### Code review instructions
- Re-run:
  - `docmgr doctor --ticket HK3S-0004 --stale-after 30`
- Confirm there are no remaining warnings or errors for the ticket.

### Technical details
- Commands run:
  - `git diff --check`
  - `docmgr doctor --ticket HK3S-0004 --stale-after 30`

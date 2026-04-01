---
Title: Diary
Ticket: HK3S-0021
Status: active
Topics:
    - keycloak
    - vault
    - kubernetes
    - email
    - gitops
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../hair-booking/docs/keycloak-vault-smtp-sync-playbook.md
      Note: Current app-side SMTP contract and legacy helper workflow
    - Path: docs/keycloak-vault-smtp-reconciler-pattern.md
      Note: Canonical platform explanation of the SMTP secret flow
    - Path: gitops/kustomize/keycloak/deployment.yaml
      Note: Existing Keycloak runtime package that the reconciler will extend
    - Path: gitops/kustomize/keycloak/keycloak-hair-booking-smtp-sync-configmap.yaml
      Note: Reconciler implementation and idempotence logic
    - Path: gitops/kustomize/keycloak/keycloak-hair-booking-smtp-sync-cronjob.yaml
      Note: Runtime wiring for the SMTP reconciler
    - Path: gitops/kustomize/keycloak/keycloak-vault-auth.yaml
      Note: Existing namespace-local Vault auth pattern to copy
ExternalSources: []
Summary: Chronological implementation diary for adding the hair-booking Keycloak SMTP reconciler on K3s and replacing the remaining manual sync step.
LastUpdated: 2026-04-01T09:01:12.997480601-04:00
WhatFor: Continue or review the reconciler implementation without reconstructing the shell history.
WhenToUse: Use when validating the design intent, replaying the rollout, or checking what failed and what was verified during the SMTP reconciler work.
---


# Diary

## Goal

Capture the implementation of the K3s-native Keycloak SMTP reconciler for
`hair-booking`, including the current-state doc cleanup, the ticket setup, the
reconciler manifests, and the live validation steps.

## Step 1: Update current-state docs and create the reconciler ticket

The first part of this task was documentation hygiene. Before adding more K3s
machinery, the app-side docs needed to stop implying that Coolify and the older
AppRole helper were still the primary live path. That cleanup matters because
the reconciler ticket is explicitly about replacing the last manual step, not
about rediscovering which deployment or which Keycloak instance is live.

After that cleanup, I opened this K3s ticket so the remaining work could be
tracked where it belongs: in the GitOps repo that owns the Keycloak package,
Vault Kubernetes auth roles, and the cluster-native reconciliation path.

### Prompt Context

**User prompt (verbatim):** "ok. first, update what can already be updated in the docs, then create a new ticket to create the reconciler job, add tasks, and then work off the ticket, committing appropriately and keeping a diary."

**Assistant interpretation:** Refresh the stale docs to reflect the real K3s deployment and current SMTP state, then create a new K3s ticket for the reconciler job and use that ticket as the implementation record.

**Inferred user intent:** Move from one-off operator fixes to a tracked, replayable, cluster-native SMTP reconciliation workflow with the docs and commits kept in sync.

**Commit (code):** `3092e9a` — `docs: describe keycloak smtp secret reconciliation`

### What I did

- Updated the app-side SMTP sync playbook to reflect the live K3s deployment,
  the current K3s Vault secret, and the fact that AppRole is now legacy
  operator workflow.
- Updated the Coolify deployment document to mark Coolify as rollback-only and
  K3s as the canonical live deployment.
- Fixed the legacy helper so explicit `TF_VAR_keycloak_*` overrides are honored
  instead of being clobbered by `terraform/.envrc`.
- Created ticket `HK3S-0021` and added this diary.
- Replaced the placeholder task list with a phased implementation queue for the
  reconciler work.

### Why

- The docs were stale in exactly the places that would confuse the next step.
- The reconciler belongs in the K3s repo because that repo owns the Keycloak
  manifests and Vault Kubernetes auth wiring.
- The helper bug had already produced one wrong-target sync, so it was worth
  fixing before using the old helper for further validation.

### What worked

- The app-side docs could be updated cleanly without inventing any new system
  behavior.
- The ticket scaffold in the K3s repo was straightforward to create and fill.

### What didn't work

- N/A so far.

### What I learned

- The legacy helper remained useful for targeted validation, but only after it
  stopped overriding explicit Keycloak admin endpoint choices.
- The missing reconciler is now the only meaningful manual edge in the SMTP
  flow; the secret shape and realm config shape are already stable.

### What was tricky to build

- The main subtlety was keeping “legacy but still useful” separate from
  “canonical now.” AppRole and the old helper are still operational references,
  but they should not be described as the steady-state K3s design.

### What warrants a second pair of eyes

- The final resource split between Keycloak’s existing service account and a new
  dedicated reconciler service account.
- Whether a `CronJob` or an Argo sync `Job` is the better reconciliation model
  for Vault-driven SMTP drift.

### What should be done in the future

- Implement the reconciler resources and validate them on the cluster.

### Code review instructions

- Review the updated app-side docs first:
  - `/home/manuel/code/wesen/hair-booking/docs/keycloak-vault-smtp-sync-playbook.md`
  - `/home/manuel/code/wesen/hair-booking/docs/deployments/hair-booking-coolify.md`
- Review the helper bug fix:
  - `/home/manuel/code/wesen/hair-booking/ttmp/2026/03/24/HAIR-010--separate-hair-booking-keycloak-realm-and-add-signup-social-login/scripts/configure_hosted_keycloak_smtp_and_smoke.sh`
- Then review this ticket scaffold and task list.

### Technical details

Key commands run:

```bash
docmgr ticket create-ticket --ticket HK3S-0021 --title "Reconcile hair-booking Keycloak SMTP from Vault on K3s" --topics keycloak,vault,kubernetes,email,gitops
docmgr doc add --ticket HK3S-0021 --doc-type reference --title "Diary"
git -C /home/manuel/code/wesen/hair-booking commit -m "docs: update deployment and smtp sync guidance"
```

## Step 2: Implement and validate the K3s-native reconciler

The implementation work stayed inside the Keycloak package in the K3s repo so
the reconciler could reuse the existing `keycloak` namespace, the existing
bootstrap-admin secret, and the existing Vault Secrets Operator connection. The
goal was to make the SMTP sync path look like the rest of the platform:
namespace-local service account, Vault-authenticated secret mirror, and a small
idempotent runtime job that touches only the realm `smtpServer` block.

The most important design correction happened during validation. I initially
tried to keep the reconciler hash inside realm custom attributes, but that
turned out to be the wrong boundary. Keycloak already masks the SMTP password
on readback, and the custom realm metadata was not a good place to anchor
reconciler bookkeeping. The final design keeps the desired-state hash in a
namespace-local `ConfigMap` instead.

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Build the K3s reconciler job, validate it against the live Keycloak realm, and keep the ticket diary current with the exact rollout and failures.

**Inferred user intent:** Replace the last manual SMTP drift-repair step with a repeatable in-cluster control loop that is reviewed and documented like the rest of the K3s platform.

**Commit (code):** `f1612d2` — `keycloak: reconcile hair-booking smtp from vault`

### What I did

- Added the dedicated Vault policy and Kubernetes auth role for the SMTP
  reconciler.
- Added `ServiceAccount`, `Role`, `RoleBinding`, `VaultAuth`,
  `VaultStaticSecret`, reconciler `ConfigMap`, state `ConfigMap`, and `CronJob`
  resources under `gitops/kustomize/keycloak`.
- Implemented the reconciler script in
  `gitops/kustomize/keycloak/keycloak-hair-booking-smtp-sync-configmap.yaml`.
- Rendered the Keycloak Kustomize package and reapplied the Keycloak package on
  the cluster.
- Ran manual one-off jobs from the CronJob to prove the first run updated the
  realm and the second run returned `in-sync`.
- Read back the realm from `https://auth.yolo.scapegoat.dev` to confirm the
  `smtpServer` block matched Vault and to remove the earlier experimental
  custom attributes.

### Why

- The SMTP secret belongs to Keycloak realm state, not to the `hair-booking`
  app pod.
- Secret-driven drift does not map well to Argo sync hooks because Vault
  rotations do not create Git commits.
- The Keycloak package already owned the namespace-local control-plane inputs,
  so the reconciler belonged there.

### What worked

- The `VaultStaticSecret` mirrored `kv/apps/hair-booking/prod/ses` into
  `Secret/keycloak-hair-booking-smtp` cleanly.
- The manual validation runs produced the expected sequence:
  first `updated`, then `in-sync`.
- The state `ConfigMap` solved the password-masking/idempotence problem cleanly.

### What didn't work

- The first implementation path tried to persist the desired hash in Keycloak
  realm attributes. That was the wrong place for reconciler state, so I pivoted
  to a namespace-local `ConfigMap`.
- I also briefly left the CronJob wired to a nonexistent
  `KUBERNETES_BEARER_TOKEN` env source. That had to be corrected to the pod's
  service-account token file at
  `/var/run/secrets/kubernetes.io/serviceaccount/token`.
- During one validation pass I forgot to export the Tailscale kubeconfig, which
  caused `kubectl` to fall back to the wrong context.

### What I learned

- Realm-side SMTP reconciliation is best treated as runtime drift management,
  not as static config embedded in Terraform or Git.
- Keycloak's masked password readback makes visible-field comparison
  insufficient by itself.
- The right persistence boundary for reconciler bookkeeping is Kubernetes state
  near the CronJob, not Keycloak realm metadata.

### What was tricky to build

- The hardest part was idempotence. The reconciler needs to know whether the
  desired SMTP payload, including the password, has already been applied, but
  Keycloak intentionally hides that password on reads. The final approach was:
  compute a deterministic hash over the desired SMTP payload and the secret
  path, store it in `ConfigMap/keycloak-hair-booking-smtp-sync-state`, and
  compare that hash together with the visible realm `smtpServer` fields before
  deciding whether to `PUT` the realm.

### What warrants a second pair of eyes

- Whether the 15-minute CronJob schedule is the right drift-repair interval.
- Whether Vault Kubernetes auth policy/role bootstrap should become a separate
  declarative control loop instead of remaining script-driven.

### What should be done in the future

- Let Argo sync the `keycloak` application to adopt the pushed reconciler
  resources.
- Consider a shared platform pattern for other realm-side Keycloak secrets so
  this does not stay `hair-booking`-specific forever.

### Code review instructions

- Start with the package entry point:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/kustomization.yaml`
- Then review the reconciler resources:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/keycloak-hair-booking-smtp-sync-configmap.yaml`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/keycloak-hair-booking-smtp-sync-cronjob.yaml`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/keycloak-hair-booking-smtp-secret.yaml`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/keycloak-hair-booking-smtp-sync-state-configmap.yaml`
- Validate with:
  - `kubectl kustomize /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak`
  - one manual job run from `CronJob/keycloak-hair-booking-smtp-sync`
  - one second manual job run that should return `in-sync`
  - a realm readback from `https://auth.yolo.scapegoat.dev/admin/realms/hair-booking`

### Technical details

Key commands run:

```bash
kubectl kustomize /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak >/tmp/keycloak-rendered.yaml
VAULT_ADDR=https://vault.yolo.scapegoat.dev VAULT_TOKEN=$(cat /home/manuel/.vault-token) /home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-kubernetes-auth.sh
kubectl apply -k /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak
kubectl -n keycloak create job --from=cronjob/keycloak-hair-booking-smtp-sync keycloak-hair-booking-smtp-sync-manual-20260401091600
kubectl -n keycloak logs job/keycloak-hair-booking-smtp-sync-manual-20260401091600
kubectl -n keycloak create job --from=cronjob/keycloak-hair-booking-smtp-sync keycloak-hair-booking-smtp-sync-manual-20260401091630
kubectl -n keycloak logs job/keycloak-hair-booking-smtp-sync-manual-20260401091630
git -C /home/manuel/code/wesen/2026-03-27--hetzner-k3s commit -m "keycloak: reconcile hair-booking smtp from vault"
git -C /home/manuel/code/wesen/2026-03-27--hetzner-k3s push origin main
```

## Step 3: Update the docs to describe the new SMTP secret path

Once the implementation was in place and pushed, the docs needed to stop
describing the K3s reconciler as future intent. The user also explicitly asked
for the current SMTP secret handling to be written down, which required both a
platform-side explanation and a lighter app-side contract update.

The useful distinction here is that the app repo still documents the secret
shape and the legacy replay helper, but the K3s repo now documents the actual
steady-state control loop. That split is now explicit instead of implied.

### Prompt Context

**User prompt (verbatim):** "do 1 then stop, i'll sync for you. \n\nThen update the documentation to write up how we handle the SMTP secrets now."

**Assistant interpretation:** Push the implementation commit so the user can Argo-sync it, then update both repos' docs to explain the steady-state SMTP secret flow without performing the Argo sync myself.

**Inferred user intent:** Separate rollout control from documentation work while making the new SMTP secret path understandable to the next operator.

**Commit (code):** Pending

### What I did

- Pushed `f1612d2` to `origin/main` in the K3s repo.
- Added a new K3s platform document describing the realm-side SMTP reconciler
  pattern.
- Updated the K3s `README.md` start-here links to point at that new document.
- Updated the app-side SMTP playbook so it now describes the K3s reconciler as
  the steady-state control loop and demotes the AppRole helper to legacy
  operator workflow. The app-side doc change was committed in the `hair-booking`
  repo as `56f9ccb`.
- Updated this ticket's tasks, changelog, and status sections.

### Why

- The implementation was already real; the docs needed to stop presenting it as
  future work.
- The platform-side and app-side docs serve different purposes and both matter:
  one explains the control plane, the other preserves the app contract and the
  emergency replay tools.

### What worked

- The new dedicated K3s doc made the control-plane split much easier to explain
  cleanly than trying to hide it inside an unrelated deployment playbook.
- The app-side doc could stay shorter once it linked to the platform-side
  pattern instead of re-explaining every K3s detail.

### What didn't work

- My first broad patch against the app-side playbook failed because the file had
  shifted since the earlier read. I reran `sed` and patched the exact current
  sections instead.

### What I learned

- This topic becomes confusing quickly if the docs blur together three separate
  responsibilities:
  Vault as source of truth, Kubernetes as runtime secret mirror, and Keycloak
  as mutable realm-state target.

### What was tricky to build

- The tricky part was being precise about ownership. The K3s Kubernetes
  resources are Git-defined and intended for Argo ownership, but Vault
  policy/role bootstrap is still script-driven. The docs had to say that
  plainly without implying that Argo already owns everything.

### What warrants a second pair of eyes

- Whether the new K3s doc belongs as a standalone playbook or should later be
  folded into a broader Keycloak operator guide.

### What should be done in the future

- After the user syncs Argo, verify the `keycloak` application tree includes
  the new reconciler resources at the pushed revision.

### Code review instructions

- Review the new K3s platform doc:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/keycloak-vault-smtp-reconciler-pattern.md`
- Review the `README.md` link addition:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/README.md`
- Review the app-side contract update:
  - `/home/manuel/code/wesen/hair-booking/docs/keycloak-vault-smtp-sync-playbook.md`

### Technical details

Key commands run:

```bash
git -C /home/manuel/code/wesen/2026-03-27--hetzner-k3s push origin main
sed -n '1,260p' /home/manuel/code/wesen/hair-booking/docs/keycloak-vault-smtp-sync-playbook.md
rg -n "SMTP|smtp|VaultStaticSecret|hair-booking-smtp|keycloak-hair-booking-smtp-sync|Keycloak" /home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs /home/manuel/code/wesen/2026-03-27--hetzner-k3s/README.md -g '*.md'
```

## Step 4: Finish the operator verification documentation

After the implementation and the first documentation pass, there was still one
practical gap: the docs explained the control plane, but they did not yet tell
an operator exactly what to look for in Argo CD after syncing the `keycloak`
application. That is the first question a real operator asks once the manifests
are pushed.

I closed that gap by adding an explicit Argo CD verification section to the K3s
SMTP reconciler document and a pointer from the app-side playbook back to that
platform doc. This keeps the “how do I verify adoption?” answer close to the
resource model that Argo actually owns.

### Prompt Context

**User prompt (verbatim):** "peerfect, finish writing up the documentation"

**Assistant interpretation:** Complete the remaining operator-facing documentation details so the SMTP reconciler rollout and verification path are fully written down.

**Inferred user intent:** Leave the ticket and platform docs in a state where the next person does not need to ask follow-up questions to understand how to verify the rollout.

**Commit (code):** Pending

### What I did

- Added an Argo CD verification section to the K3s SMTP reconciler playbook.
- Added a short pointer in the app-side SMTP playbook so readers know where the
  canonical Argo verification steps live.
- Updated the ticket changelog to record the final documentation pass.

### Why

- The resource ownership model only becomes useful if the operator knows where
  to inspect it in Argo CD after a sync.

### What worked

- The new section fit naturally into the platform-side validation chapter.

### What didn't work

- N/A.

### What I learned

- The most useful final docs are usually not more architecture prose. They are
  the concrete verification steps the operator reaches for immediately.

### What was tricky to build

- The main constraint was avoiding duplicated explanations across repos. The
  K3s doc now owns Argo verification, while the app-side doc simply points to
  it.

### What warrants a second pair of eyes

- Whether the Argo verification section should later be lifted into a more
  general Keycloak operator document if more realm-side reconcilers appear.

### What should be done in the future

- After the user syncs Argo, compare the live `keycloak` application tree
  against the documented expected resources and note any differences back in
  this ticket if needed.

### Code review instructions

- Review:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/keycloak-vault-smtp-reconciler-pattern.md`
  - `/home/manuel/code/wesen/hair-booking/docs/keycloak-vault-smtp-sync-playbook.md`

### Technical details

Key commands run:

```bash
sed -n '1,320p' /home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/keycloak-vault-smtp-reconciler-pattern.md
sed -n '1,260p' /home/manuel/code/wesen/hair-booking/docs/keycloak-vault-smtp-sync-playbook.md
```

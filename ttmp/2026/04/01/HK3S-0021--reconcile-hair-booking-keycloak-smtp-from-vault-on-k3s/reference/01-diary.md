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
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/deployment.yaml
      Note: Existing Keycloak runtime package that the reconciler will extend
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/keycloak-vault-auth.yaml
      Note: Existing namespace-local Vault auth pattern to copy
    - Path: /home/manuel/code/wesen/hair-booking/docs/keycloak-vault-smtp-sync-playbook.md
      Note: Current app-side SMTP contract and legacy helper workflow
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

**Commit (code):** Pending

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

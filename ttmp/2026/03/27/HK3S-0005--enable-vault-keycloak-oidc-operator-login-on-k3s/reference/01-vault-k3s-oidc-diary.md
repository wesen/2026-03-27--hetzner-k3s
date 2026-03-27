---
Title: Vault K3s OIDC implementation diary
Ticket: HK3S-0005
Status: active
Topics:
    - vault
    - k3s
    - keycloak
    - oidc
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../../wesen/terraform/keycloak/apps/infra-access/envs/hosted/main.tf
      Note: Shared Keycloak client config extended to allow the K3s Vault callback
    - Path: scripts/bootstrap-vault-oidc.sh
      Note: Canonical helper used to configure the K3s Vault OIDC backend and operator mappings
    - Path: scripts/validate-vault-oidc-config.sh
      Note: Validation helper for the Vault-side OIDC state and Keycloak redirect acceptance
    - Path: vault/policies/operators/admin.hcl
      Note: Operator admin policy copied into the K3s repo for reviewable ownership
    - Path: vault/policies/operators/ops-readonly.hcl
      Note: Read-only operator policy copied into the K3s repo for reviewable ownership
ExternalSources: []
Summary: Chronological diary for recreating the Keycloak-backed human operator login path on the K3s Vault instance.
LastUpdated: 2026-03-27T14:30:00-04:00
WhatFor: Use this to review the implementation trail, including the shared Keycloak change, Vault-side bootstrap, and operator-login validation.
WhenToUse: Read this when continuing or reviewing the K3s Vault OIDC implementation ticket.
---

# Vault K3s OIDC implementation diary

## Goal

Capture the implementation work for recreating the Keycloak-backed operator login path on the K3s Vault instance so human access stops depending on the root token.

## Step 1: Reconfirm the old OIDC design and decide whether to reuse or fork it

The first thing I did in this ticket was ground the new K3s OIDC work in the already-working Coolify-era implementation rather than designing a second identity model from scratch. I re-read the old Vault auth-hardening playbook and the shared Keycloak Terraform environment that currently manages the `infra` realm and `vault-oidc` client. That made the design choice much clearer: the K3s Vault should reuse the existing `infra` realm, the existing `vault-oidc` browser client, and the existing operator group names, then add the new Vault hostname as an additional callback instead of creating a second operator realm for no benefit.

That reuse decision matters because operator identity is one of the worst places to create near-duplicate systems. If the old and new Vaults had different realms, different group names, or different client IDs, then operator onboarding and incident response would get more complicated right as the platform is still being migrated. Reusing the existing Keycloak control plane keeps the "who is an infra admin" question single-sourced while still allowing the K3s Vault to stand up independently at its own hostname.

### Prompt Context

**User prompt (verbatim):** "ok, implement."

**Assistant interpretation:** Start executing the OIDC ticket, not just planning it, and keep the same ticket/diary/commit discipline as before.

**Inferred user intent:** Recreate the working human-operator auth path on the K3s Vault with real implementation and real validation.

### What I did
- Re-read the `HK3S-0005` plan and tasks.
- Inspected the shared Keycloak Terraform env at:
  - `/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/hosted/main.tf`
  - `/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/hosted/terraform.tfvars`
- Re-read the old Vault OIDC operator playbook and bootstrap script from the Terraform repo.
- Verified the live `infra` realm discovery document at `https://auth.scapegoat.dev/realms/infra/.well-known/openid-configuration`.

### Why
- The K3s Vault should match the established operator identity model unless there is a strong reason to diverge.
- Reusing the existing realm and client reduces migration risk and avoids duplicated operator setup.

### What worked
- The old control-plane shape was documented well enough to reuse directly.
- The existing client already supported localhost CLI callbacks, so the only IdP-side change needed for K3s was the new UI callback hostname.

### What didn't work
- Some early attempts to pipe 1Password output through shell parsing were more fragile than they needed to be. That was a tooling annoyance, not a design problem.

### What I learned
- The shared `infra` realm and `vault-oidc` client are already the right long-term operator boundary.
- The cleanest migration path is additive: extend the existing Keycloak client, then recreate the Vault-side auth mount on K3s.

### What was tricky to build
- The subtle part was resisting the urge to make the K3s Vault "more independent" than necessary. Separate infrastructure is good; duplicated identity topology is not.

### What warrants a second pair of eyes
- Whether the shared `infra` realm should remain the long-term operator identity boundary even after more infrastructure migrates to K3s.

### What should be done in the future
- Apply the Keycloak client callback expansion first, then configure the K3s Vault OIDC auth mount.

### Code review instructions
- Review:
  - `/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/hosted/main.tf`
  - `/home/manuel/code/wesen/terraform/ttmp/2026/03/25/TF-008-VAULT-AUTH-HARDENING--implement-vault-auth-hardening-with-keycloak-and-a-go-end-to-end-example/playbooks/01-vault-oidc-operator-playbook.md`
  - `/home/manuel/code/wesen/terraform/coolify/services/vault/scripts/apply_auth_hardening.sh`
- Confirm the reused realm/client/group model is the right choice for the K3s Vault.

### Technical details
- Existing realm: `infra`
- Existing client: `vault-oidc`
- Existing groups:
  - `infra-admins`
  - `infra-readonly`

## Step 2: Extend the shared Keycloak client and add the K3s-side OIDC bootstrap scaffold

With the design choice settled, I changed the shared Keycloak Terraform environment to allow the new K3s Vault UI callback URI and applied that change live before touching Vault. That rollout order matters because a Vault role that points at an unapproved redirect URI will fail during login in a way that looks like Vault trouble even though the real problem is the IdP. By extending the Keycloak client first, I made the K3s Vault auth mount safe to configure next.

In parallel, I added the K3s-side repo artifacts that will own the new OIDC configuration here instead of leaving it as tribal knowledge copied from the old Coolify repo. That included local copies of the operator ACL policies, a bootstrap script for the Vault auth backend, a validation script that checks both Vault state and the Keycloak redirect acceptance, and a dedicated K3s operator playbook.

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Make the OIDC rollout executable in code and keep the implementation trail reviewable.

**Inferred user intent:** Replace "we know how this used to work" with repo-managed assets that fit the K3s deployment.

### What I did
- Updated `/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/hosted/main.tf` to add:
  - `https://vault.yolo.scapegoat.dev/ui/vault/auth/oidc/oidc/callback`
  to both the valid redirect URIs and post-logout redirect URIs.
- Ran Terraform plan and apply in the shared Keycloak env.
- Committed and pushed the shared Terraform repo checkpoint.
- Added K3s repo files:
  - `vault/policies/operators/admin.hcl`
  - `vault/policies/operators/ops-readonly.hcl`
  - `scripts/bootstrap-vault-oidc.sh`
  - `scripts/validate-vault-oidc-config.sh`
  - `ttmp/.../playbooks/02-vault-k3s-oidc-operator-playbook.md`

### Why
- The IdP has to accept the new callback before Vault can safely use it.
- The K3s repo needs to own its Vault-side OIDC state explicitly, even if the identity source remains shared.

### What worked
- The Keycloak plan was a clean in-place update.
- The existing client secret and group names could be reused directly.
- The old operator policy model copied cleanly into the K3s repo.

### What didn't work
- Nothing conceptually failed here. The only friction was small shell-tooling noise while checking secrets and live state.

### What I learned
- The shared Keycloak client update was smaller than expected: one additional UI callback plus harmless group-description drift reconciliation.
- The K3s-side bootstrap can stay very close to the old Vault-side implementation because the auth model itself did not need to change.

### What was tricky to build
- The important design edge was ownership. The IdP redirect list belongs in the shared Terraform repo; the Vault auth mount, policies, and group aliases belong in the K3s repo.

### What warrants a second pair of eyes
- Whether we eventually want the shared Keycloak client to drop the old Coolify Vault hostname after all migration tickets are complete.

### What should be done in the future
- Apply the K3s Vault-side bootstrap.
- Validate both browser and CLI login against the new hostname.

### Code review instructions
- Review:
  - `/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/hosted/main.tf`
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-oidc.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-oidc.sh)
  - [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-vault-oidc-config.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-vault-oidc-config.sh)
  - [02-vault-k3s-oidc-operator-playbook.md](../playbooks/02-vault-k3s-oidc-operator-playbook.md)
- Confirm the new callback hostname and the K3s-local Vault-side ownership split are sensible.

### Technical details
- Shared Terraform commit:
  - `666f4be` `feat(keycloak): allow k3s vault oidc callback`

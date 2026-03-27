---
Title: Vault K3s OIDC implementation diary
Ticket: HK3S-0005
Status: active
Topics:
    - vault
    - k3s
    - infra
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
LastUpdated: 2026-03-27T14:10:00-04:00
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

## Step 3: Apply the Vault-side OIDC auth backend and validate the static config

Once the shared Keycloak client allowed the new callback URI, I configured the K3s Vault instance itself. The bootstrap script enabled `oidc/`, wrote the backend config using the existing `vault-oidc` client credentials, wrote the `operators` role, copied in the `admin` and `ops-readonly` policies, and created the external identity groups and aliases for `infra-admins` and `infra-readonly`. After that, I ran the config validation helper to verify both the Vault-side shape and that Keycloak no longer rejected the K3s UI redirect URI.

This step is where the migration actually became real. Before it, the K3s Vault had only machine auth through Kubernetes. After it, the cluster had a human-auth control plane again, with the same operator groups as the old Vault deployment but fully wired into the new hostname.

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Apply the operator-login slice live, not just in documentation.

**Inferred user intent:** Make the K3s Vault practically operable by humans through Keycloak.

### What I did
- Ran [bootstrap-vault-oidc.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-oidc.sh) against `https://vault.yolo.scapegoat.dev`.
- Reused the shared Keycloak `vault-oidc` client secret from:
  - `/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/hosted/terraform.tfvars`
- Confirmed live Vault state:
  - `oidc/` exists in `vault auth list`
  - `auth/oidc/role/operators` has the expected redirect URIs and group mapping
  - external group aliases exist for `infra-admins` and `infra-readonly`
- Ran [validate-vault-oidc-config.sh](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-vault-oidc-config.sh).

### Why
- Human operator auth needs to exist on the live K3s Vault before later tickets can assume the root token is break-glass only.
- Config validation should happen immediately so callback and alias mistakes are caught before browser testing.

### What worked
- The bootstrap script applied cleanly on the first run.
- Keycloak accepted the new K3s UI callback URI.
- The `operators` role and group aliases matched the old control-plane design.

### What didn't work
- Nothing failed in this step after the earlier Keycloak callback change landed.

### What I learned
- The old operator-login model ports cleanly when the shared IdP side is already in place.
- The shared Keycloak client plus repo-local Vault bootstrap is the right ownership split.

### What was tricky to build
- The only subtle piece was carrying the client secret across repos without drifting into ad hoc one-off commands. Reusing the existing shared Terraform secret source kept that manageable.

### What warrants a second pair of eyes
- Whether the client secret should eventually move out of the shared Terraform tfvars file into Vault or 1Password to reduce local secret sprawl.

### What should be done in the future
- Validate real browser and CLI login with temporary test users.

### Code review instructions
- Re-run:
  - `export VAULT_ADDR=https://vault.yolo.scapegoat.dev`
  - `export VAULT_TOKEN=<k3s-vault-root-token>`
  - `export VAULT_OIDC_CLIENT_SECRET="$(sed -n 's/^vault_oidc_client_secret  = \"\\(.*\\)\"$/\\1/p' /home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/hosted/terraform.tfvars)"`
  - `./scripts/bootstrap-vault-oidc.sh`
  - `./scripts/validate-vault-oidc-config.sh`

### Technical details
- Bootstrap summary:
  - auth path: `oidc/`
  - default role: `operators`
  - admin group alias: `infra-admins`
  - readonly group alias: `infra-readonly`

## Step 4: Prove positive and negative login outcomes with temporary Keycloak users

The final technical proof in this ticket was real human-style login, not just reading Vault config back. I used the shared Keycloak admin API to create two temporary users in the `infra` realm:

- `vault-oidc-admin-smoke-20260327` in `infra-admins`
- `vault-oidc-deny-smoke-20260327` in no Vault-authorized group

That gave me a clean validation split. The admin user should be admitted and receive the `admin` identity policy. The ungrouped user should be denied before Vault issues a token.

The positive browser validation worked after I stopped treating the OIDC popup as a normal manually-driven browser tab. Vault’s UI expects the popup flow to remain attached to its parent page so it can hand the login result back through window state. My first manual tab interaction broke that assumption and produced a misleading `Expired or missing OAuth state` error. Re-running the UI flow as one scripted parent-plus-popup interaction succeeded and landed the operator on the Vault dashboard.

The CLI validation was even cleaner. Using `vault login -method=oidc role=operators skip_browser=true no-store=true -format=json`, I let Vault print the auth URL, opened it in a browser, and let the localhost callback complete. For the allowed user, Vault returned a token carrying the `admin` identity policy. For the ungrouped user, Vault rejected the callback with `failed to fetch groups: "groups" claim not found in token`, which is a deny result before token issuance.

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Leave behind real proof that the OIDC login path works for the right humans and fails for the wrong ones.

**Inferred user intent:** Validate the operational path, not just the config shape.

### What I did
- Created temporary validation users in the `infra` realm through the Keycloak admin API.
- Validated browser login to `https://vault.yolo.scapegoat.dev` for the admin-group user.
- Validated CLI login for the admin-group user and captured the returned identity policy set.
- Validated CLI rejection for the ungrouped user.
- Deleted both temporary users after the test completed.

### Why
- Human-auth tickets are not credible unless both the allow path and the deny path are exercised.
- Temporary users let the validation happen without depending on an existing human operator account.

### What worked
- Browser login landed on the Vault dashboard for the `infra-admins` test user.
- CLI login returned a token carrying:
  - `identity_policies: ["admin"]`
- Negative CLI login failed before token issuance for the ungrouped user.

### What didn't work
- My first manual browser attempt broke Vault’s popup state handoff and produced:

```text
Authentication failed: Vault login failed. Expired or missing OAuth state.
```

- That was a test-harness problem, not a platform problem. A single scripted popup flow fixed it.

### What I learned
- The Vault UI popup flow is sensitive to how the popup window is controlled during testing.
- In the current Keycloak setup, an ungrouped user gets no `groups` claim at all, so Vault denies earlier than a classic bound-claims mismatch.

### What was tricky to build
- The hardest part here was not the IdP or Vault config. It was getting a real browser validation path that exercised the same popup semantics the Vault UI expects.

### What warrants a second pair of eyes
- Whether it would be worth later adding a realm-level default group or a dedicated test-only outsider group so the negative path yields a more explicit bound-claims mismatch instead of a missing-claim error.

### What should be done in the future
- Move to `HK3S-0006` so in-cluster controllers can consume Vault through the now-working human/operator control plane.

### Code review instructions
- Positive CLI re-run:
  - `export VAULT_ADDR=https://vault.yolo.scapegoat.dev`
  - `vault login -method=oidc role=operators skip_browser=true no-store=true -format=json`
- Confirm the resulting token carries `identity_policies: ["admin"]` for an `infra-admins` test user.
- Negative CLI re-run:
  - perform the same command as a user not in `infra-admins` or `infra-readonly`
- Confirm Vault rejects the callback and issues no token.

### Technical details
- Positive CLI result:
  - `identity_policies: ["admin"]`
  - `metadata.role: "operators"`
- Negative CLI result:

```text
Code: 400. Errors:

* failed to fetch groups: "groups" claim not found in token
```

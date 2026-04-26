---
Title: Terraform-managed infra operator group membership for Vault OIDC
Ticket: HK3S-0026
Status: active
Topics:
    - keycloak
    - vault
    - terraform
    - oidc
    - k3s
DocType: design-doc
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../terraform/keycloak/apps/infra-access/envs/k3s-parallel/main.tf
      Note: Terraform lookup and group membership resource for wesen Vault admin access
    - Path: ../../../../../../../terraform/keycloak/apps/infra-access/envs/k3s-parallel/outputs.tf
      Note: Membership-management output
    - Path: ../../../../../../../terraform/keycloak/apps/infra-access/envs/k3s-parallel/variables.tf
      Note: Feature flag and username variable for managed membership
    - Path: scripts/bootstrap-vault-oidc.sh
      Note: Vault OIDC role and group-alias bootstrap contract
ExternalSources: []
Summary: Design and implementation notes for managing the existing `wesen` Keycloak user membership in `infra-admins` through Terraform so Vault OIDC issues an admin policy token.
LastUpdated: 2026-04-26T16:45:00-04:00
WhatFor: Use when reviewing why the `wesen` user can write k3s app secrets to Vault through OIDC.
WhenToUse: Use when Vault OIDC login fails with a missing `groups` claim or when adding operator access to the `infra` realm.
---


# Terraform-managed infra operator group membership for Vault OIDC

## Executive summary

Vault OIDC login for `https://vault.yolo.scapegoat.dev` failed for the `wesen` user with:

```text
failed to fetch groups: "groups" claim not found in token
```

That error means Keycloak authenticated the user, but the OIDC token did not contain a `groups` claim acceptable to Vault's `auth/oidc/role/operators` role. The Yolo Vault operator model requires the user to be in one of two Keycloak groups in the `infra` realm:

- `infra-admins` for Vault admin/write access.
- `infra-readonly` for Vault read-only access.

For the current Discord bot deployment work, `wesen` needs to write a new runtime secret at `kv/apps/discord-ui-showcase/prod/runtime`, so `infra-admins` is the correct group.

This ticket makes that membership declarative in Terraform by adding a `keycloak_user_groups` resource in `/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/k3s-parallel`. It looks up the existing `wesen` user instead of creating a duplicate user, then grants additive membership in `infra-admins` with `exhaustive = false`.

The change was applied successfully against `https://auth.yolo.scapegoat.dev`. A Keycloak Admin API readback confirmed that `wesen` is now a member of `infra-admins`.

## Current-state architecture

The relevant systems are:

```text
Terraform keycloak/apps/infra-access/envs/k3s-parallel
  -> manages Keycloak realm infra on auth.yolo.scapegoat.dev
  -> manages groups infra-admins and infra-readonly
  -> manages client vault-oidc
  -> manages groups claim protocol mapper

Vault at vault.yolo.scapegoat.dev
  -> auth mount oidc/
  -> role operators
  -> accepts only groups infra-admins or infra-readonly
  -> maps infra-admins to Vault admin policy
  -> maps infra-readonly to Vault ops-readonly policy
```

Before this ticket, Terraform managed the groups and OIDC client, but not the `wesen` user's membership in `infra-admins`. That left the user able to authenticate to Keycloak while still being rejected by Vault because Keycloak emitted no `groups` claim.

## Implemented Terraform shape

The implementation uses a data source for the existing user:

```hcl
data "keycloak_user" "wesen_operator" {
  count = var.manage_wesen_vault_admin_membership ? 1 : 0

  realm_id = module.realm.id
  username = var.wesen_operator_username
}
```

Then it grants additive group membership:

```hcl
resource "keycloak_user_groups" "wesen_vault_admin" {
  count = var.manage_wesen_vault_admin_membership ? 1 : 0

  realm_id = module.realm.id
  user_id  = data.keycloak_user.wesen_operator[0].id

  group_ids = [
    keycloak_group.infra_admins.id,
  ]

  exhaustive = false
}
```

The important design decision is `exhaustive = false`. That means this Terraform resource ensures `infra-admins` membership but does not remove other user groups that may be managed manually, by another Terraform slice, or by an identity-provider flow.

## Variables added

```hcl
variable "manage_wesen_vault_admin_membership" {
  type        = bool
  default     = true
  description = "When true, look up the existing wesen user in the infra realm and add it to infra-admins for Vault operator write access."
}

variable "wesen_operator_username" {
  type        = string
  default     = "wesen"
  description = "Existing Keycloak username to grant infra-admins membership for Vault OIDC operator access."
}
```

The default behavior now manages `wesen` membership. If a future environment does not have a `wesen` user, set `manage_wesen_vault_admin_membership = false` for that environment.

## Commands run

The Terraform plan was run with the k3s Keycloak bootstrap-admin credentials loaded from the Kubernetes Secret, without printing the password:

```bash
K3S_REPO=/home/manuel/code/wesen/2026-03-27--hetzner-k3s
TF_DIR=/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/k3s-parallel
export KUBECONFIG="$K3S_REPO/.cache/kubeconfig-tailnet.yaml"
export TF_VAR_keycloak_url="https://auth.yolo.scapegoat.dev"
export TF_VAR_keycloak_username="$(kubectl -n keycloak get secret keycloak-bootstrap-admin -o jsonpath='{.data.username}' | base64 -d)"
export TF_VAR_keycloak_password="$(kubectl -n keycloak get secret keycloak-bootstrap-admin -o jsonpath='{.data.password}' | base64 -d)"
cd "$TF_DIR"
AWS_PROFILE=manuel terraform plan -out=/tmp/hk3s-0026-infra-access.plan
AWS_PROFILE=manuel terraform apply -auto-approve /tmp/hk3s-0026-infra-access.plan
```

Plan summary:

```text
Plan: 1 to add, 2 to change, 0 to destroy.
```

Apply summary:

```text
Apply complete! Resources: 1 added, 2 changed, 0 destroyed.
```

The two in-place changes were descriptions on existing groups. The new resource was:

```text
keycloak_user_groups.wesen_vault_admin[0]
```

## Validation

After apply, a Keycloak Admin API readback showed the user's groups:

```text
infra-admins
```

The next human validation is:

```bash
export VAULT_ADDR=https://vault.yolo.scapegoat.dev
vault login -method=oidc role=operators
vault token lookup
```

Expected Vault token result:

```text
identity_policies    [admin]
```

After that, the Discord bot secret seed should work:

```bash
cd /home/manuel/code/wesen/2026-04-20--js-discord-bot
set -a
source ./.envrc
set +a
ttmp/2026/04/26/DISCORD-BOT-K3S-SHOWCASE-DEPLOY--deploy-discord-ui-showcase-bot-to-k3s/scripts/01-seed-discord-ui-showcase-vault.sh
```

## References

- `/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/k3s-parallel/main.tf` — Terraform user lookup and group membership resource.
- `/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/k3s-parallel/variables.tf` — feature flag and username variable.
- `/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/k3s-parallel/outputs.tf` — membership management output.
- `/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/k3s-parallel/terraform.tfvars.example` — example variable values.
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-oidc.sh` — Vault OIDC role/group alias bootstrap logic.
- `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0005--enable-vault-keycloak-oidc-operator-login-on-k3s/playbooks/02-vault-k3s-oidc-operator-playbook.md` — operator OIDC playbook.

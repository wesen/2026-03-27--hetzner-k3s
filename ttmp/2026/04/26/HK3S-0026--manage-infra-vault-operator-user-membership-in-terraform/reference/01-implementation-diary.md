---
Title: Implementation diary
Ticket: HK3S-0026
Status: active
Topics:
    - keycloak
    - vault
    - terraform
    - oidc
    - k3s
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../terraform/keycloak/apps/infra-access/envs/k3s-parallel/terraform.tfvars.example
      Note: Example operator membership variables
    - Path: ttmp/2026/04/26/HK3S-0026--manage-infra-vault-operator-user-membership-in-terraform/design-doc/01-terraform-managed-infra-operator-group-membership-for-vault-oidc.md
      Note: Design summary and validation evidence
ExternalSources: []
Summary: Chronological diary for adding Terraform-managed `wesen` membership in `infra-admins` for Yolo Vault OIDC access.
LastUpdated: 2026-04-26T16:45:00-04:00
WhatFor: Record commands, decisions, validation, and follow-up for HK3S-0026.
WhenToUse: Read before changing the infra-access k3s-parallel Terraform environment or debugging Vault OIDC group-claim failures.
---


# Diary

## Goal

Make the existing `wesen` user in the Keycloak `infra` realm receive Vault admin/write access through the declarative Terraform-managed group membership path.

## Step 1: Create the k3s docmgr ticket and confirm the Terraform design

I created a new docmgr ticket in the Hetzner k3s repository using `docmgr --root ttmp`, then inspected the existing Keycloak Terraform provider schema and the `infra-access/envs/k3s-parallel` Terraform environment. The first attempt accidentally reused an existing ticket ID (`HK3S-0022`), so I removed the newly-created duplicate workspace and recreated the ticket as `HK3S-0026`.

The key design decision was to avoid creating or importing the `wesen` user resource. The provider has a `keycloak_user` data source and a `keycloak_user_groups` resource, so Terraform can look up the existing user and manage just the additive `infra-admins` membership.

### Prompt Context

**User prompt (verbatim):** "alright, let's set it up, you'll probably have to import the wesen user which is already present? Create a docmgr ticket in ../2026-03-27--hetzner-k3s (with docmgr --root ...)"

**Assistant interpretation:** Create a ticket in the k3s repo, then implement the Terraform change that grants the existing `wesen` Keycloak user Vault write/admin access by managing its `infra-admins` group membership.

**Inferred user intent:** The user wants the Vault OIDC fix to be durable and declarative, not a one-off Keycloak UI change.

**Commit (code):** N/A — no git commit was requested or made.

### What I did

- Ran `docmgr --root ttmp status --summary-only` in `/home/manuel/code/wesen/2026-03-27--hetzner-k3s`.
- Accidentally created duplicate `HK3S-0022`, discovered an existing completed `HK3S-0022`, removed the new duplicate workspace, and recreated the ticket as `HK3S-0026`.
- Added a design doc and this implementation diary.
- Ran Terraform provider schema discovery with `AWS_PROFILE=manuel` because the S3 backend needs AWS credentials:

```bash
cd /home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/k3s-parallel
AWS_PROFILE=manuel terraform providers schema -json >/tmp/keycloak-schema.json
```

- Confirmed the provider has:
  - `data.keycloak_user`
  - `resource.keycloak_user_groups`

### Why

- The user suggested import might be necessary. The data-source-plus-membership-resource shape avoids import while still managing the desired group membership declaratively.
- `exhaustive = false` avoids Terraform removing other groups from the `wesen` user.

### What worked

- `docmgr --root ttmp` worked for the k3s repo.
- Terraform provider schema inspection worked after setting `AWS_PROFILE=manuel`.
- The provider supports exactly the resource shape needed.

### What didn't work

- Initial ticket ID `HK3S-0022` was ambiguous because an older completed ticket already used it.
- Running Terraform schema without AWS credentials failed with:

```text
Error: No valid credential sources found
Error: failed to refresh cached credentials, no EC2 IMDS role found
```

### What I learned

- The keycloak provider can manage group membership without owning the user object.
- The k3s Terraform S3 backend needs `AWS_PROFILE=manuel` in this operator shell.

### What was tricky to build

- Avoiding Terraform ownership mistakes was the main sharp edge. Managing a whole existing user would require import and could drift on profile fields. Managing only `keycloak_user_groups` with `exhaustive = false` gives the desired Vault access with a smaller ownership surface.

### What warrants a second pair of eyes

- Whether `wesen` should remain hard-coded as the default operator username or eventually become a list of operator usernames.

### What should be done in the future

- Consider generalizing this to a `vault_admin_usernames` set if more operators need admin access.

### Code review instructions

- Start with `/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/k3s-parallel/main.tf`.
- Review the `keycloak_user_groups.wesen_vault_admin` resource and confirm `exhaustive = false`.
- Review `variables.tf` for the feature flag and username variable.

### Technical details

Provider schema check for `keycloak_user_groups` showed:

```text
realm_id required
user_id required
group_ids required
exhaustive optional
```

## Step 2: Implement, plan, apply, and verify membership

I added Terraform code in the `infra-access/envs/k3s-parallel` environment to look up the existing `wesen` user and add it to `infra-admins`. Then I validated, planned, applied, and read back the group membership through the Keycloak Admin API.

The apply succeeded and the readback showed `infra-admins`, which should make the next `vault login -method=oidc role=operators` issue a Vault token with the `admin` identity policy.

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Complete the Terraform implementation and apply it live if the plan is safe.

**Inferred user intent:** Restore usable Vault write access for the `wesen` user so the Discord bot k3s secret can be seeded.

**Commit (code):** N/A — no git commit was requested or made.

### What I did

Modified:

- `/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/k3s-parallel/main.tf`
- `/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/k3s-parallel/variables.tf`
- `/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/k3s-parallel/outputs.tf`
- `/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/k3s-parallel/terraform.tfvars.example`

Added:

```hcl
data "keycloak_user" "wesen_operator" {
  count = var.manage_wesen_vault_admin_membership ? 1 : 0

  realm_id = module.realm.id
  username = var.wesen_operator_username
}

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

Validated and planned with:

```bash
cd /home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/k3s-parallel
terraform fmt main.tf variables.tf outputs.tf
AWS_PROFILE=manuel terraform validate
```

The first plan attempt without Keycloak variables failed because this environment's `terraform.tfvars` does not contain the admin credentials:

```text
No value for required variable "keycloak_url"
No value for required variable "keycloak_username"
No value for required variable "keycloak_password"
```

Then I loaded them from the in-cluster Keycloak bootstrap secret without printing the password:

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

### Why

- The Vault `operators` OIDC role requires a `groups` claim containing `infra-admins` or `infra-readonly`.
- `infra-admins` maps to the Vault `admin` policy, which includes `kv/*` write access.
- The Discord bot secret seeding needs write access under `kv/apps/discord-ui-showcase/prod/runtime`.

### What worked

- Terraform found the existing `wesen` user:

```text
data.keycloak_user.wesen_operator[0]: Read complete ... [id=87ace363-6ab4-4145-9396-c8f5fdb12ba7]
```

- Terraform created the group membership resource:

```text
keycloak_user_groups.wesen_vault_admin[0]: Creation complete ... [id=infra/87ace363-6ab4-4145-9396-c8f5fdb12ba7]
```

- Keycloak Admin API readback showed:

```text
infra-admins
```

### What didn't work

- Public kubeconfig access timed out for the bootstrap-admin secret read. The tailnet kubeconfig worked:

```text
/home/manuel/code/wesen/2026-03-27--hetzner-k3s/.cache/kubeconfig-tailnet.yaml
```

### What I learned

- The existing `wesen` user is present in the `infra` realm on `auth.yolo.scapegoat.dev`.
- Adding the group membership did not require importing the user.
- The current `terraform.tfvars` intentionally omits Keycloak admin credentials, so operator sessions need to provide them via `TF_VAR_*` or another secure mechanism.

### What was tricky to build

- The plan included two in-place group description updates because the Terraform config has descriptions and the live groups lacked them. This was safe and expected, but it means the apply was not only the group membership resource.

### What warrants a second pair of eyes

- Confirm whether `infra-admins` is the right permanent group for `wesen`, or whether `infra-readonly` plus a narrower temporary Vault policy would be preferable for routine work.
- Confirm that managing this membership with a hard-coded default username is acceptable for the k3s-parallel environment.

### What should be done in the future

- Retry Vault CLI login:

```bash
export VAULT_ADDR=https://vault.yolo.scapegoat.dev
vault login -method=oidc role=operators
vault token lookup
```

- Confirm `identity_policies` includes `admin`.
- Seed the Discord bot runtime secret.

### Code review instructions

- Validate Terraform:

```bash
cd /home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/k3s-parallel
AWS_PROFILE=manuel terraform validate
```

- Re-plan with Keycloak credentials from the bootstrap Secret or a secure operator source.
- Verify Keycloak membership without printing secrets:

```bash
curl -sS -H "Authorization: Bearer $KC_TOKEN" \
  "https://auth.yolo.scapegoat.dev/admin/realms/infra/users/$USER_ID/groups" \
  | jq -r '.[].name'
```

### Technical details

Files changed by this step are in the Terraform repo, not the k3s repo. The docmgr ticket is in the k3s repo because the operational problem belongs to the k3s Vault/Keycloak deployment.

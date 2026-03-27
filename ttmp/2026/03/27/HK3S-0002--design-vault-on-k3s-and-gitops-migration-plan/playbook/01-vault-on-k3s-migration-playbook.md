---
Title: Vault on K3s migration playbook
Ticket: HK3S-0002
Status: active
Topics:
    - vault
    - k3s
    - argocd
    - gitops
    - migration
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../terraform/keycloak/apps/infra-access/envs/hosted/main.tf
      Note: Playbook phase for extending Vault OIDC redirects
    - Path: cloud-init.yaml.tftpl
    - Path: gitops/applications/demo-stack.yaml
      Note: Reference pattern for adding additional Argo applications
ExternalSources: []
Summary: Operator-oriented sequence for implementing the recommended Vault-on-K3s migration in safe phases.
LastUpdated: 2026-03-27T11:24:00-04:00
WhatFor: Use this as the execution sequence once the design is approved.
WhenToUse: Read this before starting the actual implementation tickets for Vault on K3s.
---


# Vault on K3s migration playbook

## Purpose

Move Vault onto the Hetzner K3s cluster without breaking the current Coolify-hosted consumers, then establish the default secret-delivery path that later application migrations can use.

## Environment Assumptions

- The K3s cluster from this repo is already live and reachable.
- Argo CD is healthy.
- The current Coolify-hosted Vault remains available during the migration.
- The AWS KMS key used for Vault auto-unseal already exists.
- You can update Keycloak Terraform for Vault OIDC redirect URIs.
- You can update DNS for a new Vault hostname under the K3s environment.

## Commands and Sequence

## Phase 1: Prepare the parallel K3s Vault hostname and OIDC redirects

1. Add the new Vault hostname to DNS.
2. Extend the Keycloak `infra-access` client redirects to include the new Vault UI callback.
3. Apply the Keycloak Terraform change before deploying the K3s Vault.

Representative Terraform check:

```bash
cd /home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/hosted
terraform init
terraform plan
terraform apply
```

## Phase 2: Add Vault as an Argo CD application

1. Create repo-owned Vault values.
2. Add `gitops/applications/vault.yaml`.
3. Sync the application in Argo CD.

Representative validation:

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl -n argocd get applications
```

Expected result:

- Argo CD shows a new `vault` application progressing or healthy.

## Phase 3: Initialize the K3s Vault

1. Wait for the Vault pod and ingress to come up.
2. Run `vault operator init` once.
3. Store recovery material in 1Password.
4. Verify health endpoint and auto-unseal behavior.

Representative validation:

```bash
curl -sS 'https://<new-vault-host>/v1/sys/health?standbyok=true'
```

Expected result:

- `initialized=true`
- `sealed=false`

## Phase 4: Recreate auth and policy baseline

1. Enable OIDC auth for operators.
2. Enable Kubernetes auth for in-cluster workloads.
3. Recreate the current least-privilege policies.
4. Recreate the required secret paths in the new Vault.

Representative policy flow:

```text
enable oidc
  -> configure discovery URL, client id, client secret
enable kubernetes
  -> configure host / CA / reviewer token
write admin / readonly / app policies
write kv test secrets
```

## Phase 5: Install Vault Secrets Operator

1. Add a new Argo CD application for VSO.
2. Create `VaultConnection` and `VaultAuth`.
3. Create one test `VaultStaticSecret`.
4. Verify the synced Kubernetes `Secret`.

Expected result:

- the synced `Secret` exists in the target namespace,
- and a test pod can read it.

## Phase 6: Migrate one simple app secret first

Recommended first target:

- `kv/apps/hair-booking/prod/ses`

Reason:

- smallest blast radius,
- easy policy validation,
- no special file rendering.

Exit criteria:

- VSO sync works,
- positive and negative reads behave as expected,
- no Coolify dependency is needed for that secret in the K3s test namespace.

## Phase 7: Migrate CoinVault secret delivery

1. Sync `runtime` and `pinocchio` data through VSO.
2. Mount YAML payloads as files.
3. Inject env-style runtime keys from Kubernetes `Secret` data.
4. Remove `COINVAULT_BOOTSTRAP_MODE=vault` from the K3s deployment shape.

Expected result:

- CoinVault starts without AppRole bootstrap in Kubernetes.

## Phase 8: Add backup and audit follow-ups

1. Add a snapshot CronJob.
2. Upload snapshots to Hetzner Object Storage.
3. Define restore drill.
4. Enable audit logging with a documented retention path.

## Failure Modes

- If Argo deploys Vault but OIDC login fails:
  - check Keycloak redirect URIs first.
- If Vault pod restarts sealed:
  - check AWS KMS credentials and seal stanza first.
- If VSO cannot sync:
  - check Kubernetes auth config, service account binding, and policy paths.
- If migrated app still depends on AppRole:
  - confirm its deployment contract was actually switched away from bootstrap mode.

## Exit Criteria

- K3s-hosted Vault is healthy on its own hostname.
- OIDC operator login works.
- Kubernetes auth works.
- VSO can sync at least one real secret path.
- One migrated app secret path works from K3s without Coolify.
- Cutover plan for later app migrations is documented and reviewable.

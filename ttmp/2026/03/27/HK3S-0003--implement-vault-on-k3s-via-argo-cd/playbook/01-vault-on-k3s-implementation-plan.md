---
Title: Vault on K3s implementation plan
Ticket: HK3S-0003
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
RelatedFiles: []
ExternalSources: []
Summary: "Ordered implementation plan for recreating Vault on the K3s cluster without cutting over the existing Coolify Vault."
LastUpdated: 2026-03-27T11:36:00-04:00
WhatFor: "Use this to execute the first implementation slice of Vault on K3s."
WhenToUse: "Read this before editing the repo or touching the live cluster for the Vault deployment."
---

# Vault on K3s implementation plan

## Purpose

Deploy a new Vault instance onto the Hetzner K3s cluster through Argo CD, using the official HashiCorp Helm chart, AWS KMS auto-unseal, Traefik ingress, and local-path-backed Raft storage.

## Scope

This ticket does not cut over the existing Coolify Vault and does not dismantle any Coolify infrastructure. The goal is to recreate the deployment on K3s first, validate it, and leave cutover/auth/operator follow-up work for later tickets.

## Environment Assumptions

- `vault.yolo.scapegoat.dev` resolves to the K3s node.
- The current Coolify Vault remains available at `vault.app.scapegoat.dev`.
- The AWS KMS key `alias/vault-scapegoat-dev-unseal` already exists.
- The K3s cluster is reachable through `kubeconfig-91.98.46.169.yaml`.
- Argo CD is healthy in the cluster.

## Execution Sequence

## Task 1: Create the repo-managed Vault application scaffold

Deliverables:

- `gitops/applications/vault.yaml`
- bootstrap helper for the non-git AWS secret
- ticket docs updated to reflect the new task breakdown

Current implementation choices for this first pass:

- official HashiCorp Helm chart `vault` version `0.32.0`
- Argo CD owns the `Application`; the chart itself is fetched from the Helm repo
- single-replica HA mode with integrated Raft so the config shape still matches the intended long-term Vault mode
- `local-path` PVC for the Raft data volume
- Traefik ingress on `vault.yolo.scapegoat.dev`
- cert-manager issuer `letsencrypt-prod`
- Vault listener TLS disabled internally, with TLS terminated at Traefik
- AWS KMS auto-unseal credentials injected from a non-git Kubernetes `Secret`
- injector and CSI disabled for the first deploy to keep the surface area narrow

Success criteria:

- the repo contains a reviewable Argo CD application manifest,
- the secret bootstrap path is explicit and not committed with credentials.

## Task 2: Bootstrap the AWS KMS secret in the cluster

Create a Kubernetes `Secret` in namespace `vault` that provides:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`

Success criteria:

- the secret exists in the cluster,
- no credentials are committed to git.

Operator path:

```bash
export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml
export AWS_PROFILE=manuel
./scripts/bootstrap-vault-aws-kms-secret.sh
```

## Task 3: Apply the Vault Argo CD application

Use Argo CD to install Vault from the official chart with:

- single replica,
- Raft storage,
- `local-path` PVC,
- Traefik ingress,
- cert-manager issuer,
- UI service enabled,
- injector and CSI disabled for the first pass.

Success criteria:

- Vault pod schedules,
- PVC binds,
- ingress appears,
- application reaches `Synced` and `Healthy` or at least a reviewable progressing state.

## Task 4: Verify public reachability and pod health

Check:

- pod status
- services
- ingress
- certificate
- `GET /v1/sys/health`
- UI reachability

Success criteria:

- `vault.yolo.scapegoat.dev` responds,
- the pod is stable enough to initialize.

Validation commands used in this ticket:

```bash
export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml
kubectl -n vault get pods,pvc,ingress
kubectl -n argocd get application vault -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{"\n"}'
curl -k -I https://vault.yolo.scapegoat.dev/
curl -k https://vault.yolo.scapegoat.dev/v1/sys/health
```

## Task 5: Initialize and record handoff

Initialize the K3s Vault once, store recovery material outside git, and document:

- the exact operator command path,
- what was stored where,
- what follow-up work remains.

Success criteria:

- the new Vault is initialized,
- AWS KMS auto-unseal is validated by restart testing,
- the diary captures the operator flow.

Operator commands used in this ticket:

```bash
export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml
kubectl -n vault exec vault-0 -- sh -lc 'vault operator init -format=json'
kubectl -n vault exec vault-0 -- sh -lc 'vault status -format=json'
kubectl -n vault delete pod vault-0
kubectl -n vault exec vault-0 -- sh -lc 'vault status -format=json'
```

Recovery material handling in this ticket:

- not written into repo files
- not left on the server
- stored in 1Password vault `Private` as secure note `vault yolo scapegoat dev k3s init 2026-03-27`

## Failure Modes

- If the pod stays Pending:
  check PVC, affinity, or storage class issues first.
- If the pod starts but loops sealed:
  check the AWS secret injection and seal stanza first.
- If ingress exists but UI is unreachable:
  check Traefik annotations, service target, and TLS issuance.
- If Argo fails to render:
  inspect the chart values and application manifest before touching the cluster manually.

## Exit Criteria

- The repo contains the Vault Argo CD application scaffold and bootstrap helper.
- The live cluster runs a K3s-hosted Vault instance on `vault.yolo.scapegoat.dev`.
- The deployment is documented in the implementation diary.
- The next-ticket boundaries are explicit: OIDC, Kubernetes auth, VSO, and app secret recreation.

## Operational Notes

- This ticket exposed an operator sharp edge: `admin_cidrs` had been pinned to an earlier workstation IP. When the local public IP changed, both SSH and the Kubernetes API became unreachable until the firewall was updated through a targeted Terraform apply.
- Long-term, this should be replaced with a more stable admin-access path, such as a VPN/Tailscale boundary, a bastion, or a less brittle allowlist maintenance process.

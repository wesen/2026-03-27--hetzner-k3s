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

## Task 5: Initialize and record handoff

Initialize the K3s Vault once, store recovery material outside git, and document:

- the exact operator command path,
- what was stored where,
- what follow-up work remains.

Success criteria:

- the new Vault is initialized,
- AWS KMS auto-unseal is validated by restart testing,
- the diary captures the operator flow.

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

---
Title: Vault on K3s and GitOps Migration Design
Ticket: HK3S-0002
Status: active
Topics:
    - vault
    - k3s
    - argocd
    - gitops
    - terraform
    - migration
DocType: design-doc
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/docker/entrypoint.sh
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/docs/deployments/coinvault-coolify.env.example
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/internal/bootstrap/bootstrap.go
      Note: Current CoinVault AppRole bootstrap and secret rendering flow
    - Path: ../../../../../../../terraform/coolify/services/vault/docker-compose.yaml
      Note: Current Vault deployment definition used as baseline evidence
    - Path: ../../../../../../../terraform/coolify/services/vault/policies/app-coinvault-prod.hcl
    - Path: ../../../../../../../terraform/coolify/services/vault/policies/app-hair-booking-prod.hcl
    - Path: ../../../../../../../terraform/coolify/services/vault/scripts/provision_vault_via_coolify_host.sh
    - Path: ../../../../../../../terraform/coolify/services/vault/scripts/seed_coinvault_runtime_and_pinocchio_secrets.sh
    - Path: ../../../../../../../terraform/coolify/services/vault/vault.hcl.awskms.example
      Note: Current single-node Raft plus AWS KMS auto-unseal baseline
    - Path: ../../../../../../../terraform/keycloak/apps/infra-access/envs/hosted/main.tf
      Note: Existing Vault OIDC redirect and group mapping Terraform
    - Path: cloud-init.yaml.tftpl
      Note: Current K3s bootstrap boundary showing why Vault should be day-two GitOps state
    - Path: gitops/applications/demo-stack.yaml
    - Path: gitops/kustomize/demo-stack/kustomization.yaml
ExternalSources:
    - https://developer.hashicorp.com/vault/docs/platform/k8s/helm/examples
    - https://developer.hashicorp.com/vault/docs/auth/kubernetes
    - https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso
    - https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso/sources/vault
    - https://developer.hashicorp.com/vault/docs/audit
    - https://developer.hashicorp.com/vault/docs/commands/operator/raft
Summary: Evidence-backed design for moving Vault from the current Coolify deployment onto the Hetzner K3s cluster, then using Vault plus GitOps-native secret delivery to migrate future applications safely.
LastUpdated: 2026-03-27T11:15:00-04:00
WhatFor: Use this to understand the current state, choose the target Vault architecture on K3s, and execute a phased migration from Coolify toward Argo CD-managed application delivery.
WhenToUse: Read this before implementing Vault on K3s, choosing a Kubernetes secret delivery model, or migrating hair-booking and CoinVault onto the cluster.
---


# Vault on K3s and GitOps Migration Design

## Executive Summary

The current platform already has a working Vault, but it lives in the wrong control plane for the long-term direction. Today Vault is a single-node service deployed through Coolify, updated through a host-driven script that reaches into the Coolify container and mutates Laravel models directly. The new Hetzner environment is also single-node, but it is already anchored around K3s, Argo CD, cert-manager, Traefik, and GitOps-managed manifests. If the long-term goal is to move infrastructure and applications away from Coolify and into K3s, Vault should move first so it becomes the stable secret control plane that later migrations can depend on.

The recommended target is:

1. run Vault inside K3s as its own Argo CD-managed application,
2. keep it single-node for now, with integrated Raft storage on a persistent volume,
3. preserve AWS KMS auto-unseal rather than regressing to manual unseal,
4. keep human login on Keycloak OIDC,
5. switch in-cluster consumers from AppRole to Kubernetes auth,
6. use the Vault Secrets Operator as the default migration path for application secrets,
7. keep the old Coolify Vault online temporarily during parallel validation and cutover.

This is the best fit for the current real environment. It matches the cluster you already have, avoids putting more critical control-plane state into Coolify, and gives migrated applications a GitOps-compatible secret flow without forcing every app to implement a Vault client immediately.

## Problem Statement and Scope

The user wants to move infrastructure away from Coolify and semi-manual operations toward K3s and Argo CD. The first piece should be Vault, because Vault is not just another app. It is the system that later apps depend on for secrets. If Vault remains outside the new platform, every future migration will either keep one foot in Coolify or will have to solve secrets ad hoc.

The concrete design problem is broader than “how do I install Vault on Kubernetes.” The real questions are:

1. What is the current live state of Vault, app secret paths, and operator auth?
2. What is the current live shape of the K3s cluster and what constraints does it impose?
3. What is the right target architecture for a single-node K3s cluster that is still early in its lifecycle?
4. How should future apps consume secrets once they move into Kubernetes?
5. How do we migrate without breaking the current Coolify-hosted consumers?

This document covers those questions. It does not implement the move yet. It produces the evidence-backed architecture, migration phases, implementation guidance, and operator playbook needed to execute the move safely.

## Current-State Analysis

### 1. Current Vault deployment lives in Coolify, not in Terraform or GitOps

The canonical current Vault deployment is defined as a Coolify service in [`docker-compose.yaml`](/home/manuel/code/wesen/terraform/coolify/services/vault/docker-compose.yaml), not as a Kubernetes workload or Terraform-managed host process. The service runs `hashicorp/vault:1.20`, exposes `VAULT_ADDR` and `VAULT_API_ADDR` as `https://vault.app.scapegoat.dev`, mounts `/vault/config/vault.hcl`, and persists `/vault/data` and `/vault/logs` through Docker volumes (lines 1-19). The matching example config in [`vault.hcl.awskms.example`](/home/manuel/code/wesen/terraform/coolify/services/vault/vault.hcl.awskms.example) uses integrated Raft storage and AWS KMS auto-unseal, with `api_addr` set to the public hostname and `cluster_addr` bound to the container network (lines 1-23).

Operationally, the deployment path is host-driven and specialized. The provisioner script [`provision_vault_via_coolify_host.sh`](/home/manuel/code/wesen/terraform/coolify/services/vault/scripts/provision_vault_via_coolify_host.sh) SSHes to the Coolify host, enters the Coolify container, updates internal Coolify service/application records, writes the managed `vault.hcl`, injects AWS credentials, and restarts the service (lines 43-166). That works, but it is tightly coupled to Coolify internals and is exactly the kind of control plane the new K3s direction is supposed to avoid.

Observed live behavior still matches that architecture. `curl -I https://vault.app.scapegoat.dev/ui/` returned `HTTP/2 200`, and `curl https://vault.app.scapegoat.dev/v1/sys/health?standbyok=true` returned a healthy Vault 1.20.4 response with `initialized=true` and `sealed=false`.

### 2. Current secret layout and machine auth already exist and are useful

The good news is that the existing Vault data model is already close to what should survive the migration. The app policies in [`app-hair-booking-prod.hcl`](/home/manuel/code/wesen/terraform/coolify/services/vault/policies/app-hair-booking-prod.hcl) and [`app-coinvault-prod.hcl`](/home/manuel/code/wesen/terraform/coolify/services/vault/policies/app-coinvault-prod.hcl) are small and app-scoped. Hair-booking can read `kv/data/apps/hair-booking/prod/ses` and matching metadata (lines 1-12). CoinVault can read `kv/data/apps/coinvault/prod/runtime`, `kv/data/apps/coinvault/prod/pinocchio`, and matching metadata (lines 1-16).

That path layout is a strong starting point:

```text
kv/apps/hair-booking/prod/ses
kv/apps/coinvault/prod/runtime
kv/apps/coinvault/prod/pinocchio
```

It is clear, environment-scoped, and already reflected in app-side documentation.

Machine auth today is AppRole-centric. The helper [`generate_hair_booking_approle_material.sh`](/home/manuel/code/wesen/terraform/coolify/services/vault/scripts/generate_hair_booking_approle_material.sh) writes a role with explicit TTLs and produces JSON containing `role_id`, `secret_id`, mount, and secret path (lines 61-85). That is a reasonable pattern for off-cluster services, but it is not the best default for workloads that will run inside Kubernetes because Kubernetes-native auth can remove the need to distribute `secret_id` material to pods.

### 3. CoinVault’s current runtime contract depends on Vault but is shaped for Coolify

CoinVault is the clearest example of how the current hosted apps consume Vault. The app repo’s Coolify env example [`coinvault-coolify.env.example`](/home/manuel/code/gec/2026-03-16--gec-rag/docs/deployments/coinvault-coolify.env.example) shows the container currently receives Vault connection details plus AppRole credentials and secret paths via environment variables (lines 1-15). The bootstrap code in [`internal/bootstrap/bootstrap.go`](/home/manuel/code/gec/2026-03-16--gec-rag/internal/bootstrap/bootstrap.go) then logs into Vault with AppRole, reads `runtime` and `pinocchio` secrets, writes files under `/run/secrets/pinocchio`, and writes an environment file with session, OIDC, and MySQL values (lines 22-117 and 185-271). The container entrypoint [`docker/entrypoint.sh`](/home/manuel/code/gec/2026-03-16--gec-rag/docker/entrypoint.sh) runs that bootstrap binary only when `COINVAULT_BOOTSTRAP_MODE=vault`, then sources the generated env file before starting the server (lines 4-57).

The secret seeding helper [`seed_coinvault_runtime_and_pinocchio_secrets.sh`](/home/manuel/code/wesen/terraform/coolify/services/vault/scripts/seed_coinvault_runtime_and_pinocchio_secrets.sh) makes the current data model explicit. It writes app runtime values such as session secret, OIDC client secret, app URL, and MySQL credentials into `kv/apps/coinvault/prod/runtime`, and it writes raw `profiles_yaml` and `config_yaml` into `kv/apps/coinvault/prod/pinocchio` (lines 62-76).

This matters for the migration design because it tells us exactly what must still exist after the move:

- native env-style key/value secrets,
- file-shaped YAML payloads,
- one app that currently expects a bootstrap phase before normal startup,
- and a preference for keeping secrets out of Git and out of the app image.

### 4. Hair-booking currently depends on Vault as an external platform service

Hair-booking has less app-side implementation here, but the Terraform ticket playbook [`01-hair-booking-vault-ses-developer-handoff.md`](/home/manuel/code/wesen/terraform/ttmp/2026/03/25/TF-010-HAIR-BOOKING-VAULT-SES--integrate-hair-booking-with-vault-for-ses-smtp-credentials/playbooks/01-hair-booking-vault-ses-developer-handoff.md) is explicit that Vault is the source of truth for SES SMTP material at `kv/apps/hair-booking/prod/ses`, and that the current intended auth shape is AppRole with a dedicated least-privilege policy. That means the K3s design should preserve the path layout and policy style, but it does not need to preserve AppRole as the first-choice in-cluster auth path.

### 5. Current K3s cluster is single-node, GitOps-managed, and ready for platform add-ons

The new K3s cluster is already stable enough to host a platform service. The bootstrap file [`cloud-init.yaml.tftpl`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/cloud-init.yaml.tftpl) proves that K3s, cert-manager, and Argo CD are installed at first boot, and that the seeded app gets moved toward GitOps after bootstrap (lines 14-129). The live repo-managed application manifest [`gitops/applications/demo-stack.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/demo-stack.yaml) points Argo CD at the Kustomize path `gitops/kustomize/demo-stack` with automated prune/self-heal enabled (lines 1-23). The live Kustomize package [`gitops/kustomize/demo-stack/kustomization.yaml`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/demo-stack/kustomization.yaml) is already the source of truth for the demo workload (lines 1-14).

Live cluster inspection shows:

- one node `k3s-demo-1`, Kubernetes `v1.34.5+k3s1`, ready and healthy,
- default `local-path` storage class,
- Traefik ingress class,
- cert-manager and Argo CD already running,
- Argo application `demo-stack` is `Synced Healthy`,
- approximately 5.6 GiB memory available on a 7.6 GiB node,
- disk usage only ~5.7 GiB of 150 GiB on the server.

Those facts make Vault-on-K3s realistic for this environment. They also set the hard constraints:

- this is still single-node and non-HA,
- any persistent state will live on local disk,
- and we should avoid designs that require multi-node primitives today.

### 6. Current operator environment handling is too ad hoc for the target state

The repo-local Terraform `.envrc` at [`/home/manuel/code/wesen/terraform/.envrc`](/home/manuel/code/wesen/terraform/.envrc) exports live provider values directly, including Keycloak admin credentials, DigitalOcean token material, and object storage credentials, and it derives the Coolify token from `~/.config/coolify/config.json` (lines 1-60). Even if that file is only local, it captures the current habit: operator credentials are still being passed around as shell environment rather than being modeled cleanly as bootstrap exceptions or GitOps-managed secret references.

That pattern is acceptable for emergency/operator tooling, but it is not the design we should copy into Kubernetes. The K3s target should separate:

- bootstrap exceptions that must exist before Vault is reachable,
- GitOps-managed declarative references,
- and runtime workload access that should come from Vault-authenticated controllers or service accounts.

## Gap Analysis

The platform is currently split across two incompatible control planes:

1. Coolify owns Vault and some hosted app runtimes.
2. K3s plus Argo CD own the new cluster and its workloads.

That split creates four concrete migration problems:

### Gap 1: Vault lives outside the future platform

As long as Vault remains a Coolify service, every future Kubernetes app migration still depends on the old platform. That delays rather than solves the platform transition.

### Gap 2: Current machine auth is optimized for off-cluster consumers

AppRole works, but it assumes pods or containers receive static login material. That is awkward for Kubernetes workloads, where the better primitive is usually a service account token bound to Vault’s Kubernetes auth method.

### Gap 3: The cluster does not yet have a standard secret-delivery path

The current K3s repo has Argo CD and Kustomize, but no Vault integration layer. There is no Kubernetes auth config in Vault because Vault is not yet in the cluster, and there is no secret-sync controller installed. That means migrated apps would currently have to choose between:

- manual Kubernetes `Secret` objects,
- app-specific Vault client logic,
- or more bootstrap scripting.

None of those is the right default for a long-term migration program.

### Gap 4: Bootstrap material and backup/audit concerns still need a K3s-native answer

The current Vault deployment already identified follow-up needs around snapshots and audit logging in the Terraform tickets. Those needs do not disappear in Kubernetes. They simply move:

- from Docker volumes to Kubernetes PVCs,
- from host jobs to cluster jobs,
- and from Coolify runtime paths to K3s-managed workloads.

## Recommended Target Architecture

## Recommendation Summary

Use Vault-on-K3s as a first-class Argo CD-managed platform service, with the following stack:

1. Vault server deployed by Argo CD from the official HashiCorp Helm chart.
2. Single replica with integrated Raft storage on a `local-path` PVC.
3. AWS KMS auto-unseal preserved through the Vault server config.
4. Traefik ingress and cert-manager TLS, initially on a parallel hostname such as `vault.yolo.scapegoat.dev`.
5. Human auth through the existing Keycloak OIDC realm/client model.
6. Kubernetes auth enabled for in-cluster workloads and controllers.
7. Vault Secrets Operator as the default “Vault to Kubernetes Secret” bridge.
8. Agent Injector reserved for special cases that need direct file rendering or should avoid synced Kubernetes Secrets.

This is the cleanest balance between “works with the current cluster” and “scales into later app migration.”

### Why Helm for Vault itself

For platform software like Vault, the official Helm chart is the right abstraction layer. Vault has enough moving parts that recreating its StatefulSet, Services, ConfigMaps, probes, volume claims, and optional injector/operator pieces by hand in Kustomize would be unnecessary toil and a maintenance trap.

That does not conflict with the repo’s Kustomize preference. The pragmatic split should be:

- use Helm where upstream vendors already maintain a stable deployment package,
- use Argo CD to own the installation declaratively,
- keep repo-owned surrounding manifests in Kustomize where that is clearer,
- and keep app-owned workloads on Kustomize/plain YAML as before.

In other words: Argo CD is the GitOps controller, Kustomize remains the default for app manifests, and Helm is allowed for third-party platform components where it reduces risk.

### Why Vault Secrets Operator should be the default migration path

HashiCorp’s Kubernetes guidance now explicitly points Kubernetes users toward operator/injector approaches rather than forcing every app to talk to Vault directly. For this migration, the best default is the Vault Secrets Operator (VSO), not because it is the most “pure” Vault pattern, but because it matches the way the current apps are shaped.

The current apps mostly want one of two things:

- environment variables like database credentials or SMTP config,
- files like Pinocchio YAML.

VSO handles that cleanly:

- it authenticates to Vault using Kubernetes-native mechanisms,
- it can sync selected Vault data into Kubernetes `Secret` objects,
- Argo CD can manage the `VaultConnection`, `VaultAuth`, and `VaultStaticSecret` resources in Git,
- and existing Deployments can keep consuming secrets through `envFrom`, `valueFrom`, or mounted secret volumes.

That makes the app migration smaller. You do not need to force every app to embed Vault client code on day one.

### Where Agent Injector still fits

Agent Injector should remain available for two special classes of workload:

1. apps that should not persist secret material in etcd as Kubernetes Secrets,
2. apps that want files rendered directly from Vault templates with periodic refresh.

CoinVault is a plausible candidate later if you want its Pinocchio YAML to bypass a synced Kubernetes Secret. But for the first migration pass, even CoinVault can likely be simplified by letting VSO create one file-shaped secret and mounting it.

### Proposed hostname strategy

Do not cut over the current Coolify Vault hostname first. Stand up the K3s-hosted Vault on a parallel hostname first, for example:

```text
vault.yolo.scapegoat.dev
```

That recommendation is grounded in the current DNS shape. The Hetzner/K3s environment already uses `*.yolo.scapegoat.dev` for cluster-hosted operator endpoints. Keeping Vault on a parallel hostname during migration gives you:

- zero pressure to replace the current Coolify Vault immediately,
- easy side-by-side OIDC and policy validation,
- and a rollback story that does not involve emergency DNS rework.

After the K3s Vault is validated and real consumers move over, you can decide whether to:

- keep `vault.yolo.scapegoat.dev` permanently,
- or later repoint `vault.app.scapegoat.dev`.

## Target System Model

### Current state

```text
operators
  -> local shells / .envrc / Coolify host access
     -> Coolify-hosted Vault
        -> kv/apps/hair-booking/prod/ses
        -> kv/apps/coinvault/prod/runtime
        -> kv/apps/coinvault/prod/pinocchio
     -> Coolify-hosted apps or app-specific bootstrap flows
```

### Target state

```text
operators
  -> Git repo
     -> Argo CD
        -> Vault application
        -> Vault Secrets Operator application
        -> app applications

K3s cluster
  -> Vault StatefulSet
     -> Raft PVC (local-path)
     -> AWS KMS auto-unseal
     -> Traefik ingress + cert-manager TLS
     -> Keycloak OIDC for humans
     -> Kubernetes auth for workloads

  -> Vault Secrets Operator
     -> VaultConnection
     -> VaultAuth
     -> VaultStaticSecret
     -> Kubernetes Secret
     -> Deployment env vars / mounted files
```

### Secret flow for a migrated app

```text
service account token
  -> Vault kubernetes auth
     -> Vault policy
        -> allowed secret path
           -> VSO sync
              -> Kubernetes Secret
                 -> app Deployment
```

### Human auth flow

```text
operator browser / vault login
  -> Vault OIDC auth method
     -> Keycloak realm/client
        -> groups claim
           -> Vault identity/policies
```

## Detailed Design Decisions

### Decision 1: Keep the existing KV path layout

Keep the current `kv/apps/<app>/<env>/...` structure. It is already used by the current app integration scripts and policies, and it will let migration happen with minimal renaming churn.

Recommended steady-state layout:

```text
kv/
  infra/
    k3s/
      backup/
      bootstrap/
  operators/
    bootstrap/
  apps/
    hair-booking/
      prod/
        ses
    coinvault/
      prod/
        runtime
        pinocchio
```

This preserves what already works and gives space for cluster-specific operational material.

### Decision 2: Use Kubernetes auth for in-cluster workloads, keep AppRole only for transitional or off-cluster clients

The existing AppRole material is fine for today’s Coolify-hosted consumers, but it should not be the default in K3s.

Use this rule:

- Kubernetes workload in K3s: use Vault Kubernetes auth.
- Transitional off-cluster job or external automation: keep AppRole if necessary.
- Human operators: use OIDC only, not tokens or AppRole.

This sharply reduces long-lived secret distribution to pods.

### Decision 3: Put Vault and VSO in their own Argo CD applications

Do not fold Vault into `demo-stack` or into a single omnibus platform package. Create separate applications so lifecycle and troubleshooting stay clear:

```text
gitops/applications/vault.yaml
gitops/applications/vault-secrets-operator.yaml
gitops/applications/platform-root.yaml    # optional later app-of-apps root
```

That separation matters because Vault has different rollout, backup, and incident semantics than normal apps.

### Decision 4: Treat AWS KMS credentials as bootstrap exceptions

Vault needs auto-unseal material before Vault itself can help. That is a bootstrap exception. Do not pretend otherwise.

For the first K3s implementation, AWS credentials for KMS should be provided to the Vault server through a Kubernetes `Secret` that is created out-of-band and not committed to Git. The Argo-managed Helm values can reference that secret.

Later, you can improve the bootstrap story. Right now the important thing is to keep the exception explicit.

### Decision 5: Keep first implementation parallel, not in-place

Do not attempt an in-place migration of the current Coolify Vault hostname and client base in one jump. Run the K3s Vault in parallel first, validate:

- init/unseal behavior,
- OIDC login,
- Kubernetes auth,
- VSO sync,
- one real app-secret path.

Only then plan client-by-client cutover.

## Proposed Repository Shape

The current repo structure is good for the demo app but too flat for multiple platform services. The recommended shape for the next phase is:

```text
gitops/
  applications/
    vault.yaml
    vault-secrets-operator.yaml
    demo-stack.yaml
    hair-booking.yaml          # later
    coinvault.yaml             # later
  platform/
    vault/
      values/
        vault-values.yaml
      manifests/
        namespace.yaml
        ingress.yaml
        policies-bootstrap.md
    vault-secrets-operator/
      values/
        vso-values.yaml
```

You do not need to implement the entire tree at once. The important structural point is that Vault becomes a platform service with its own repo-owned values and ingress/policy-supporting manifests.

## Implementation Guide

## Phase 0: Prepare the migration without moving traffic

1. Add a new ticket and keep the migration work documented step by step.
2. Add a new Argo CD application manifest for Vault.
3. Add repo-owned Helm values for Vault.
4. Add a new DNS hostname such as `vault.yolo.scapegoat.dev`.
5. Extend the Keycloak Terraform config so the Vault OIDC client accepts the new redirect URI in addition to the existing Coolify one.

Key Keycloak change:

- [`main.tf`](/home/manuel/code/wesen/terraform/keycloak/apps/infra-access/envs/hosted/main.tf) already declares redirect URIs for `https://vault.app.scapegoat.dev/ui/vault/auth/oidc/oidc/callback` and localhost CLI callbacks (lines 1-12). Add the new K3s Vault hostname there before cutover so both old and new Vault UIs can authenticate during the transition.

## Phase 1: Deploy Vault into K3s in parallel

Deploy Vault with:

- 1 replica,
- integrated Raft storage,
- `local-path` PVC,
- AWS KMS auto-unseal,
- UI enabled,
- service and ingress compatible with Traefik,
- TLS handled at ingress,
- readiness/liveness based on Vault health.

Conceptual values sketch:

```yaml
server:
  ha:
    enabled: true
    replicas: 1
    raft:
      enabled: true
      setNodeId: true
    config: |
      ui = true
      listener "tcp" {
        address = "[::]:8200"
        cluster_address = "[::]:8201"
        tls_disable = 1
      }
      storage "raft" {
        path = "/vault/data"
      }
      seal "awskms" {
        region     = "us-east-1"
        kms_key_id = "alias/vault-scapegoat-dev-unseal"
      }
  dataStorage:
    enabled: true
    storageClass: local-path
    size: 20Gi
ui:
  enabled: true
```

Why 20Gi is reasonable for the first pass:

- current node disk usage is low,
- Vault state volume is still small compared with app data,
- and snapshots should be the real long-term recovery path anyway.

## Phase 2: Initialize and harden the new Vault

After the pod comes up:

1. run one-time `vault operator init`,
2. store root token and recovery keys in 1Password,
3. enable Keycloak OIDC auth,
4. enable the `kv` mount if not already configured,
5. recreate the policy set,
6. enable Kubernetes auth,
7. configure at least one `auth/kubernetes/role/...` for VSO and one for test workloads.

Pseudocode:

```text
deploy Vault pod
  -> verify health endpoint
  -> vault operator init
  -> store recovery material safely
  -> enable oidc auth
  -> enable kubernetes auth
  -> create admin / readonly / app policies
  -> validate browser login
```

## Phase 3: Install Vault Secrets Operator

Install VSO as its own Argo CD application. Configure:

- one `VaultConnection` that points at the in-cluster Vault service or public hostname,
- one `VaultAuth` that uses Kubernetes auth and a service account in the operator namespace,
- then app-specific `VaultStaticSecret` resources per application namespace.

The default migration shape should be:

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: coinvault-runtime
  namespace: coinvault
spec:
  type: kv-v2
  mount: kv
  path: apps/coinvault/prod/runtime
  destination:
    name: coinvault-runtime
    create: true
```

That gives the app a normal Kubernetes `Secret` while keeping Vault as the source of truth.

## Phase 4: Migrate one low-risk secret path first

Do not cut CoinVault first. Start with a simpler path such as:

- `kv/apps/hair-booking/prod/ses`

Reason:

- smaller payload,
- no file rendering,
- no bootstrap binary assumptions,
- easy positive/negative policy validation.

Validation target:

1. VSO syncs the secret into a Kubernetes Secret in a test namespace.
2. A test pod can read the intended values.
3. The same role cannot read `coinvault` or `infra` paths.

## Phase 5: Migrate CoinVault secret delivery

After VSO is proven, move CoinVault by replacing AppRole bootstrap with Kubernetes-native secret delivery.

Recommended first pass:

1. sync `kv/apps/coinvault/prod/runtime` into one Kubernetes Secret,
2. sync `kv/apps/coinvault/prod/pinocchio` into one Kubernetes Secret,
3. mount `profiles_yaml` and `config_yaml` as files from the synced secret,
4. expose runtime keys as env vars from the synced secret,
5. turn off `COINVAULT_BOOTSTRAP_MODE=vault` in the K3s deployment.

That deliberately simplifies the runtime:

```text
old:
  pod -> AppRole -> Vault -> write /run files -> source env -> start app

new:
  VSO -> Kubernetes Secret
  pod -> envFrom + secret volume -> start app
```

If later you decide CoinVault should never persist provider YAML in a Kubernetes Secret, that is the point to evaluate Agent Injector for that app only.

## Phase 6: Implement K3s-native backup and audit follow-ups

Do not leave Vault “working but under-documented” again.

Add follow-up implementation tickets for:

1. a CronJob that creates Vault Raft snapshots and uploads them to Hetzner Object Storage,
2. audit logging,
3. restore drills.

These were already open concerns in the Coolify Vault work and remain necessary here.

## API and Resource References

### Vault APIs and commands that matter

- `GET /v1/sys/health`
  readiness, sealed/unsealed, init status
- `vault operator init`
  one-time cluster initialization
- `vault auth enable oidc`
  operator auth
- `vault auth enable kubernetes`
  workload auth
- `vault write auth/kubernetes/config ...`
  connect Vault to the cluster
- `vault write auth/kubernetes/role/<role> ...`
  bind service accounts to policies
- `vault policy write <name> <file>`
  ACL policy management
- `vault kv put kv/apps/...`
  app secret source of truth
- `vault operator raft snapshot save <file>`
  backup primitive

### Kubernetes and Argo resources that matter

- `Application`
  Argo CD source of truth for platform services
- `Ingress`
  Traefik and cert-manager public exposure
- `PersistentVolumeClaim`
  Raft data persistence
- `ServiceAccount`
  workload identity anchor
- `VaultConnection`
  VSO connection to Vault
- `VaultAuth`
  VSO auth method binding
- `VaultStaticSecret`
  VSO sync of Vault KV data into a Kubernetes Secret

## Migration Plan by Application

### Hair-booking

Target:

- keep same Vault secret path,
- sync SMTP values into Kubernetes via VSO,
- let the migrated workload or supporting job read standard Kubernetes Secret data.

Expected code change:

- minimal or none at first,
- mostly deployment contract change.

### CoinVault

Target:

- remove AppRole bootstrap from normal Kubernetes deployment,
- keep same Vault paths,
- sync runtime env values and YAML payloads into Kubernetes,
- mount YAML files and env vars directly.

Expected code change:

- deployment contract change first,
- app code likely unchanged for the first K3s pass,
- optional later cleanup to remove no-longer-needed bootstrap code paths.

## Testing and Validation Strategy

## Pre-cutover validation

1. `curl https://<new-vault-host>/v1/sys/health?standbyok=true` returns healthy.
2. Vault UI login works through Keycloak on the new hostname.
3. `vault kv get` on new K3s Vault returns expected test data.
4. VSO syncs one test secret into one namespace.
5. Negative policy test proves isolation between app paths.

## Cutover validation

1. one migrated app starts without Coolify/AppRole bootstrap material,
2. redeploy does not lose secret access,
3. Argo CD shows `Synced Healthy`,
4. Vault pod restart still unseals automatically,
5. secret refresh behavior is understood and documented.

## Disaster-recovery validation

1. recovery material is stored in 1Password,
2. snapshot job produces artifacts,
3. at least one restore drill is documented.

## Risks, Tradeoffs, and Alternatives

### Risk: single-node Vault remains a single point of failure

This migration improves control-plane coherence, not availability class. The new K3s Vault is still single-node. If the node dies, Vault is still down until restored. This is acceptable for the current stage, but it is not a forever design.

### Risk: VSO copies secrets into Kubernetes Secrets

That is a conscious tradeoff. It makes migration simpler and keeps app changes small, but it means secrets are materialized in etcd. For many application config secrets that is acceptable. For higher-sensitivity material or dynamic credentials, use Agent Injector or direct Vault access later.

### Risk: bootstrap AWS credentials remain an exception

There is no magic answer here on Hetzner. Auto-unseal still needs AWS credentials before Vault can help. The design should keep that exception small and explicit rather than pretending it does not exist.

### Alternative 1: keep Vault in Coolify and only migrate apps

Rejected as the default because it preserves the split control plane and leaves every future app migration dependent on the old stack.

### Alternative 2: use AppRole for all K3s workloads

Rejected as the default because it is operationally worse than Kubernetes auth for in-cluster workloads.

### Alternative 3: force every app to call Vault directly

Rejected for the first migration phase because it increases app-specific implementation work and slows migration. Use VSO first, then only introduce direct Vault clients where there is a clear security or lifecycle reason.

### Alternative 4: hand-write Vault manifests instead of using the official Helm chart

Rejected because it would move maintenance burden onto this repo without gaining meaningful control.

## Open Questions

1. Which final public hostname should the K3s-hosted Vault keep after migration: keep a new K3s-specific hostname or reclaim `vault.app.scapegoat.dev`?
2. Do you want VSO as the standard path for all migrated apps, or only as the initial migration bridge before some apps move to Injector/direct Vault integration?
3. Which app should be the first real migration consumer after Vault itself: hair-booking for lower risk, or CoinVault because it already has the richest Vault integration?
4. Should audit logging be part of the first Vault-on-K3s implementation ticket, or explicitly scheduled immediately after first successful cutover?

## Recommended Next Tickets

1. Implement Vault on K3s as an Argo CD application.
2. Add Keycloak redirect URIs for the new Vault hostname.
3. Install Vault Secrets Operator and prove one test secret sync.
4. Migrate hair-booking SES secret delivery onto VSO.
5. Migrate CoinVault runtime and Pinocchio secret delivery onto VSO.
6. Add Vault snapshot CronJob to Hetzner Object Storage.
7. Add Vault audit logging and retention guidance.

## References

### Local repository references

- Coolify Vault service definition: [docker-compose.yaml](/home/manuel/code/wesen/terraform/coolify/services/vault/docker-compose.yaml)
- Vault server config example: [vault.hcl.awskms.example](/home/manuel/code/wesen/terraform/coolify/services/vault/vault.hcl.awskms.example)
- Coolify host-driven provisioner: [provision_vault_via_coolify_host.sh](/home/manuel/code/wesen/terraform/coolify/services/vault/scripts/provision_vault_via_coolify_host.sh)
- Existing app policies: [app-hair-booking-prod.hcl](/home/manuel/code/wesen/terraform/coolify/services/vault/policies/app-hair-booking-prod.hcl), [app-coinvault-prod.hcl](/home/manuel/code/wesen/terraform/coolify/services/vault/policies/app-coinvault-prod.hcl)
- CoinVault bootstrap implementation: [bootstrap.go](/home/manuel/code/gec/2026-03-16--gec-rag/internal/bootstrap/bootstrap.go)
- CoinVault entrypoint: [entrypoint.sh](/home/manuel/code/gec/2026-03-16--gec-rag/docker/entrypoint.sh)
- CoinVault deployment contract: [coinvault-coolify.env.example](/home/manuel/code/gec/2026-03-16--gec-rag/docs/deployments/coinvault-coolify.env.example)
- Existing K3s bootstrap shape: [cloud-init.yaml.tftpl](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/cloud-init.yaml.tftpl)
- Existing Argo app shape: [demo-stack.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/demo-stack.yaml)

### External references

- Vault Helm examples: https://developer.hashicorp.com/vault/docs/platform/k8s/helm/examples
- Vault Kubernetes auth: https://developer.hashicorp.com/vault/docs/auth/kubernetes
- Vault Secrets Operator docs: https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso
- Vault audit docs: https://developer.hashicorp.com/vault/docs/audit
- Vault Raft snapshot docs: https://developer.hashicorp.com/vault/docs/commands/operator/raft

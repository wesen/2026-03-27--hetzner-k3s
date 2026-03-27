---
Title: CoinVault application-repository Argo CD playbook
Ticket: HK3S-0007
Status: active
Topics:
    - coinvault
    - argocd
    - gitops
    - application
    - deployment
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/cmd/coinvault/cmds/profile_settings.go
      Note: Explains how profile registries are resolved from env and flags
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/cmd/coinvault/cmds/serve.go
      Note: Defines the serve-time runtime contract that Argo-managed deployments depend on
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/docker/entrypoint.sh
      Note: Maps Kubernetes env vars into the final coinvault serve invocation
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/internal/bootstrap/bootstrap.go
      Note: Documents the hosted bootstrap mode that the K3s path intentionally bypasses
ExternalSources: []
Summary: Detailed app-repository-side playbook for making CoinVault deployable under the K3s Argo CD environment.
LastUpdated: 2026-03-27T21:20:00-04:00
WhatFor: Use this to understand the CoinVault app-side contract that the K3s Argo CD deployment depends on.
WhenToUse: Read this when changing CoinVault runtime behavior, image build assumptions, config parsing, bootstrap behavior, or profile loading.
---


# CoinVault application-repository Argo CD playbook

## Purpose

This playbook teaches an intern how to think about CoinVault deployment from the application-repository side. It is not the cluster runbook. It is the guide for understanding what the app must provide so that the cluster-side GitOps system can deploy it cleanly.

The key principle is that CoinVault deployment spans two repositories:

- the app repo defines the binary, entrypoint, runtime flags, and config-decoding behavior
- the K3s repo defines the Kubernetes objects, Vault/VSO wiring, ingress, and Argo CD ownership

If you change the app contract without checking the infrastructure contract, you can break a deployment that still looks healthy at the Kubernetes level.

## Core mental model

```text
CoinVault app repo
  -> builds coinvault binary and container image
  -> defines how env vars and flags are interpreted
  -> defines bootstrap compatibility behavior

K3s repo
  -> builds/imports the image
  -> mounts secrets and file paths
  -> supplies env vars
  -> exposes the service through ingress
```

From the app side, the deployment question is:

> “Does CoinVault still accept the exact runtime contract that the K3s repo provides?”

## Files to study first

- [`cmd/coinvault/cmds/serve.go`](/home/manuel/code/gec/2026-03-16--gec-rag/cmd/coinvault/cmds/serve.go)
- [`cmd/coinvault/cmds/profile_settings.go`](/home/manuel/code/gec/2026-03-16--gec-rag/cmd/coinvault/cmds/profile_settings.go)
- [`cmd/coinvault/cmds/profile_settings_test.go`](/home/manuel/code/gec/2026-03-16--gec-rag/cmd/coinvault/cmds/profile_settings_test.go)
- [`docker/entrypoint.sh`](/home/manuel/code/gec/2026-03-16--gec-rag/docker/entrypoint.sh)
- [`internal/bootstrap/bootstrap.go`](/home/manuel/code/gec/2026-03-16--gec-rag/internal/bootstrap/bootstrap.go)
- [`docs/deployments/coinvault-argocd-deployment-playbook.md`](/home/manuel/code/gec/2026-03-16--gec-rag/docs/deployments/coinvault-argocd-deployment-playbook.md)
- partner cluster guide:
  - [`docs/coinvault-k3s-deployment-playbook.md`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/coinvault-k3s-deployment-playbook.md)

## Runtime contract that must remain stable

The K3s deployment expects these application-level behaviors:

- the container starts through [`entrypoint.sh`](/home/manuel/code/gec/2026-03-16--gec-rag/docker/entrypoint.sh)
- `COINVAULT_BOOTSTRAP_MODE=disabled` works
- `COINVAULT_PROFILE_REGISTRIES` is honored
- MySQL env vars are read from the runtime secret
- `coinvault serve` exposes `/healthz` and the auth/chat API surface

Current K3s-specific assumptions:

- `COINVAULT_SERVE_PORT=8080`
- profile registry file path: `/run/secrets/pinocchio/profiles.yaml`
- mounted Pinocchio config file path: `/run/secrets/pinocchio/config.yaml`
- timeline DB path: `/data/coinvault-timeline.db`
- turns DB path: `/data/coinvault-turns.db`

## Deployment-sensitive code paths

### Entrypoint behavior

`docker/entrypoint.sh` is the contract translator between Kubernetes env vars and the Go binary.

Important current behavior:

- prefers `COINVAULT_SERVE_PORT`
- unsets generic `PORT`
- only runs bootstrap when `COINVAULT_BOOTSTRAP_MODE=vault`
- passes `--profile-registries` when `COINVAULT_PROFILE_REGISTRIES` is set

That means an app change that renames or removes these env hooks is a deployment change, not just a refactor.

### Profile registry decoding

`profile_settings.go` matters because it decides how the runtime profile registry is interpreted. During this ticket, the cluster hit a bug where env plus CLI flag values were merged into a list-like parsed value. CoinVault originally decoded the field as a simple string and fell back to `./profile-registry.yaml`.

The lesson for future work:

- if you change config parsing, add tests in [`profile_settings_test.go`](/home/manuel/code/gec/2026-03-16--gec-rag/cmd/coinvault/cmds/profile_settings_test.go)
- verify that both env-driven and flag-driven settings still resolve correctly

### Bootstrap compatibility

`internal/bootstrap/bootstrap.go` still matters for non-Kubernetes environments. It is no longer the main runtime shape for the K3s deployment, but removing it or changing its env-file semantics can still break older hosted paths.

That means the app currently supports two secret-delivery models:

- hosted/off-cluster bootstrap mode
- Kubernetes-native secret mounting mode

## Implementation loop for app changes

1. Change application code deliberately.
2. Identify whether you changed:
   - flag names
   - env variable names
   - config file paths
   - auth assumptions
   - profile registry loading
   - DB assumptions
3. Run the relevant tests.
4. Re-read the K3s deployment contract in the infra repo.
5. Rebuild and import the image through the K3s helper.
6. Restart and validate the live deployment.

Pseudocode:

```text
edit app code
  -> go test
  -> compare against deployment.yaml contract
  -> build/import image
  -> rollout restart
  -> inspect logs and /healthz
  -> perform browser-level validation
```

## Review checklist

- Did the change alter any `COINVAULT_*` settings?
- Did the change alter bootstrap assumptions?
- Did the change alter profile registry parsing?
- Did the change alter MySQL connection assumptions?
- Did the change alter auth redirect/login behavior?

If the answer to any of those is “yes,” the K3s deployment files must be reviewed before rollout.

## Validation commands

```bash
cd /home/manuel/code/gec/2026-03-16--gec-rag
go test ./cmd/coinvault/... ./internal/bootstrap/... -count=1
```

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export K3S_NODE_HOST=91.98.46.169
./scripts/build-and-import-coinvault-image.sh
export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml
kubectl -n coinvault rollout restart deployment/coinvault
kubectl -n coinvault rollout status deployment/coinvault --timeout=180s
./scripts/validate-coinvault-k3s.sh
```

## Main takeaway

From the app-repo side, “deploying to Argo CD” really means “maintaining a stable application runtime contract that the Argo-managed Kubernetes manifests can satisfy.” Argo is not the build system. It is the reconciler. The app repo’s responsibility is to make the binary and container behavior predictable enough that GitOps can do its job.

---
Title: Implement Vault-backed GHCR image pull secrets in K3s
Ticket: HK3S-0014
Status: active
Topics:
    - argocd
    - ghcr
    - gitops
    - kubernetes
    - vault
    - packaging
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: Step-by-step implementation plan for wiring a Vault-managed GHCR dockerconfigjson secret into app workloads.
LastUpdated: 2026-03-29T10:05:00-04:00
WhatFor: Give operators a repeatable sequence for implementing private GHCR image pulls through Vault-managed credentials.
WhenToUse: Use when implementing the first `coinvault` pull-secret path or repeating the pattern for later private apps.
---

# Implement Vault-backed GHCR image pull secrets in K3s

## Purpose

This playbook describes how to implement the private-image pull path after the design is approved.

It is intentionally operational and concrete. A new intern should be able to read this, understand the system boundaries, and then carry the first implementation through without inventing the pattern again.

## Environment Assumptions

- Local checkout of:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s`
  - `/home/manuel/code/gec/2026-03-16--gec-rag`
- Access to the K3s kubeconfig:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/kubeconfig-91.98.46.169.yaml`
- `op` access to the `Private` vault
- access to create or retrieve a GitHub credential for GHCR package pulls
- working `kubectl`, `gh`, and `docmgr`

Assume the cluster already has:

- Vault
- Vault Kubernetes auth
- Vault Secrets Operator
- a working `coinvault` workload on GHCR image tags

Assume the cluster may still be using a temporary node-cache bridge. The goal of this playbook is to remove the need for that bridge.

## Commands

```bash
# 1. Confirm the current app state and exact deployment image contract
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml

kubectl -n coinvault get deployment coinvault \
  -o jsonpath='{.spec.template.spec.containers[0].image}{" "}{.spec.template.spec.containers[0].imagePullPolicy}{"\n"}'
kubectl -n argocd get application coinvault \
  -o jsonpath='{.status.sync.status} {.status.health.status} {.status.sync.revision}{"\n"}'

# 2. Decide or create the GHCR credential
# Expected minimum: a GitHub credential with package-pull capability.

# 3. Store the credential in Vault
# Example logical path, not yet implemented:
# kv/apps/coinvault/prod/image-pull
#
# Expected fields:
#   server=ghcr.io
#   username=<github-user-or-machine-account>
#   password=<token>

# 4. Add GitOps resources
# Likely files to create:
#   gitops/kustomize/coinvault/vault-static-secret-image-pull.yaml
#   gitops/kustomize/coinvault/<transform-resource>.yaml   # if needed
#
# Likely file to update:
#   gitops/kustomize/coinvault/serviceaccount.yaml

# 5. Apply and sync through Git
git status --short
git add ...
git commit -m "feat: add coinvault ghcr image pull secret"
git push origin main

# 6. Watch the resulting state
kubectl -n argocd get application coinvault \
  -o jsonpath='{.status.sync.status} {.status.health.status} {.status.sync.revision}{"\n"}'
kubectl -n coinvault get secret
kubectl -n coinvault get serviceaccount coinvault -o yaml
kubectl -n coinvault rollout status deployment/coinvault --timeout=180s

# 7. Validate the runtime path
kubectl -n coinvault get pods -l app.kubernetes.io/name=coinvault -o wide
curl -fsS https://coinvault.yolo.scapegoat.dev/healthz | jq '.'
```

### Expected logical sequence

```text
Vault path created
  -> VSO sync object reconciles
  -> dockerconfigjson secret exists in coinvault namespace
  -> ServiceAccount references imagePullSecrets
  -> rollout restarts cleanly
  -> kubelet pulls private GHCR image without manual node import
```

### Suggested implementation breakdown

1. Credential creation
   - decide whether the credential is user PAT or machine account
   - decide token scope and expiry

2. Vault data contract
   - define the path and required fields
   - document them in the repo

3. Kubernetes materialization
   - either direct `dockerconfigjson` secret sync
   - or a transform step

4. Workload attachment
   - update the `ServiceAccount`
   - keep the `Deployment` on `IfNotPresent`

5. Validation and bridge removal
   - confirm a fresh pod can pull the image
   - stop relying on containerd cache imports for normal rollout

## Exit Criteria

- `coinvault` remains `Synced Healthy`
- the `coinvault` `ServiceAccount` includes the intended `imagePullSecrets`
- the private GHCR-tagged image can be pulled after deleting the current pod
- no manual `ctr images import` step is needed to recover the rollout
- the ticket diary records the exact token, Vault path, secret shape, and validation procedure

## Notes

### Important warning: Kustomize namespace injection

Do not apply raw namespaced workload YAML without the target namespace.

This matters because:

- `gitops/kustomize/coinvault/deployment.yaml` does not declare `metadata.namespace`
- Kustomize injects the namespace during normal reconciliation
- `kubectl apply -f` on the raw file without `-n coinvault` will create a stray deployment in `default`

### Important warning: package visibility is separate from CI success

Successful GitHub Actions publish plus successful GitOps PR creation does not mean the cluster can pull the image.

Always validate the real runtime pull path.

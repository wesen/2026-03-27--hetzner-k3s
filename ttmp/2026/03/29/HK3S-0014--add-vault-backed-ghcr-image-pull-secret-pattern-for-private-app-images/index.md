---
Title: Add Vault-backed GHCR image pull secret pattern for private app images
Ticket: HK3S-0014
Status: active
Topics:
    - argocd
    - ghcr
    - gitops
    - kubernetes
    - vault
    - packaging
DocType: index
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/gec/2026-03-16--gec-rag/.github/workflows/publish-image.yaml
      Note: Current CoinVault GHCR publish and GitOps PR workflow that produces the private image being pulled
    - Path: docs/app-packaging-and-gitops-pr-standard.md
      Note: Current platform standard that now needs the private-image pull-secret extension
    - Path: gitops/kustomize/coinvault/deployment.yaml
      Note: Current CoinVault deployment already pinned to GHCR and IfNotPresent
    - Path: gitops/kustomize/coinvault/serviceaccount.yaml
      Note: Current ServiceAccount target that will need imagePullSecrets wiring
    - Path: gitops/kustomize/coinvault/vault-static-secret-runtime.yaml
      Note: Existing Vault-to-Kubernetes secret sync pattern to extend for registry auth
ExternalSources: []
Summary: ""
LastUpdated: 2026-03-29T10:40:00-04:00
WhatFor: Capture the design and implementation plan for pulling private GHCR images in-cluster through Vault-managed image pull credentials.
WhenToUse: Use when wiring a private-source app like CoinVault to a registry-backed rollout without relying on node-local image imports.
---


# Add Vault-backed GHCR image pull secret pattern for private app images

## Overview

This ticket defines the long-term pattern for private app images in this cluster.

The immediate problem is concrete:

- `coinvault` now publishes a GHCR image from its source repository
- the GitOps PR automation is working
- but the source repository is private, so the GHCR package is private too
- K3s therefore cannot anonymously pull the image during rollout

The short-term recovery was acceptable only because this is a single-node cluster:

- build the exact GHCR-tagged CoinVault image locally
- import it into the node’s containerd cache
- let `imagePullPolicy: IfNotPresent` use the cached image

That is not the long-term standard.

The long-term standard this ticket defines is:

1. Store private-registry credentials in Vault
2. Sync them into Kubernetes through VSO
3. Materialize a `kubernetes.io/dockerconfigjson` pull secret
4. Attach that secret to app `ServiceAccount`s or workload specs
5. Let the cluster pull private GHCR images normally

This ticket is now implemented for `coinvault`, with the ticket bundle preserving both the design rationale and the exact operator scripts used during rollout.

## Key Links

- [Design Doc](./design-doc/01-vault-backed-ghcr-image-pull-secret-pattern-for-private-app-images.md)
- [Implementation Playbook](./playbook/01-implement-vault-backed-ghcr-image-pull-secrets-in-k3s.md)
- [Investigation Diary](./reference/01-investigation-diary-for-vault-backed-ghcr-image-pull-secrets.md)

## Status

Current status: **active**

Scope status:

- problem reproduced
- design recommendation drafted
- implementation tasks defined
- `coinvault` image-pull path implemented
- Vault-backed `dockerconfigjson` secret proven live
- node-cache bridge removed from the normal operational story

## Topics

- argocd
- ghcr
- gitops
- kubernetes
- vault
- packaging

## Tasks

See [tasks.md](./tasks.md) for the current task list.

## Changelog

See [changelog.md](./changelog.md) for recent changes and decisions.

## Structure

- design/ - Architecture and design documents
- reference/ - Prompt packs, API contracts, context summaries
- playbooks/ - Command sequences and test procedures
- scripts/ - Temporary code and tooling
- various/ - Working notes and research
- archive/ - Deprecated or reference-only artifacts

---
Title: First app candidate decision and runtime contract
Ticket: HK3S-0007
Status: active
Topics:
    - vault
    - k3s
    - migration
    - gitops
    - applications
DocType: design-doc
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/Dockerfile
      Note: CoinVault image build contract
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/docker/entrypoint.sh
      Note: CoinVault startup contract
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/docs/deployments/coinvault-coolify.md
      Note: Existing hosted runtime contract for CoinVault
    - Path: ../../../../../../../../gec/2026-03-16--gec-rag/internal/bootstrap/bootstrap.go
      Note: Existing Vault bootstrap logic that informs the K3s secret contract
    - Path: ../../../../../../../terraform/coolify/services/vault/policies/app-hair-booking-prod.hcl
      Note: Hair-booking least-privilege policy used during candidate comparison
    - Path: ../../../../../../../terraform/ttmp/2026/03/25/TF-010-HAIR-BOOKING-VAULT-SES--integrate-hair-booking-with-vault-for-ses-smtp-credentials/playbooks/01-hair-booking-vault-ses-developer-handoff.md
      Note: Hair-booking Vault consumer contract
ExternalSources: []
Summary: Decision record for choosing CoinVault as the first K3s application migration target, plus the runtime contract the K3s deployment should satisfy.
LastUpdated: 2026-03-27T16:05:00-04:00
WhatFor: Explain why CoinVault is the right first migration target and define the concrete runtime shape we will implement on K3s.
WhenToUse: Read this before scaffolding or reviewing the first real application migration.
---

# First app candidate decision and runtime contract

## Executive Summary

The first migrated application should be CoinVault, not hair-booking. Hair-booking has the simpler Vault path, but it is not yet a real hosted application contract. CoinVault already has a Dockerfile, a documented hosted runtime contract, a known route surface, a health check, a real OIDC flow, and a concrete secret model. That makes it the only candidate that can realistically become a live K3s-hosted workload in this ticket.

The K3s design should simplify CoinVault’s old Coolify bootstrap pattern instead of copying it literally. On K3s:

- Vault remains the source of truth
- VSO should sync the runtime values into a Kubernetes `Secret`
- VSO should sync Pinocchio YAML into a separate Kubernetes `Secret`
- the deployment should consume those native Kubernetes resources directly
- external Keycloak and the existing MySQL service should remain in place for now

## Problem Statement

HK3S-0007 needs to create the first real application deployment on K3s using the new Vault/GitOps platform layers. The ticket initially left the app choice open:

- hair-booking is lower-risk from a secret standpoint
- CoinVault is higher-fidelity from a real hosted-runtime standpoint

That ambiguity is acceptable in a planning ticket, but not in an implementation ticket. We need one target whose runtime can actually be recreated now.

## Candidate Comparison

### Hair-booking

Strengths:

- very small Vault surface
- least-privilege policy already exists
- operational blast radius is low

Weaknesses:

- no real hosted runtime contract in the repo
- no concrete deployment packaging to translate into K3s
- current artifact is more of an application codebase than an already-hosted service

### CoinVault

Strengths:

- real Docker build already exists
- entrypoint contract already exists
- health check and route surface are documented
- existing Vault contract is explicit
- external dependencies are known
- current hosted deployment docs are concrete enough to translate to K8s objects

Weaknesses:

- more secrets
- MySQL plus local SQLite persistence
- OIDC callback and public URL coordination
- Pinocchio YAML payload needs file mounting

### Decision

Choose CoinVault.

Reason:

- it is the smallest realistic end-to-end hosted workload among the current candidates

## Proposed Solution

Deploy CoinVault to K3s as a local repo-managed Argo CD application in this repository.

The K3s deployment will:

- use namespace `coinvault`
- use service account `coinvault`
- use Vault Kubernetes auth through a dedicated role and policy
- sync two VSO-backed Kubernetes secrets:
  - `coinvault-runtime`
  - `coinvault-pinocchio`
- mount a PVC for:
  - `/data/coinvault-timeline.db`
  - `/data/coinvault-turns.db`
- expose the service at `coinvault.yolo.scapegoat.dev`
- keep Keycloak external at `auth.scapegoat.dev`
- keep the existing MySQL dependency external for now

## Runtime Contract

### Secret sources in Vault

The K3s Vault should contain:

- `kv/apps/coinvault/prod/runtime`
- `kv/apps/coinvault/prod/pinocchio`

### Kubernetes destination secrets

VSO should render:

- `Secret/coinvault-runtime`
- `Secret/coinvault-pinocchio`

### Deployment env and file contract

The container should run with bootstrap mode disabled and receive:

From Kubernetes env:

- `COINVAULT_AUTH_MODE=oidc`
- `COINVAULT_AUTH_PUBLIC_URL`
- `COINVAULT_OIDC_ISSUER_URL`
- `COINVAULT_OIDC_CLIENT_ID`
- `COINVAULT_OIDC_CLIENT_SECRET`
- `GEC_MYSQL_HOST`
- `GEC_MYSQL_PORT`
- `GEC_MYSQL_DATABASE`
- `GEC_MYSQL_RO_USER`
- `GEC_MYSQL_RO_PASSWORD`
- `COINVAULT_TIMELINE_DB=/data/coinvault-timeline.db`
- `COINVAULT_TURNS_DB=/data/coinvault-turns.db`
- `COINVAULT_PROFILE_REGISTRIES=/run/secrets/pinocchio/profiles.yaml`

From mounted secret files:

- `/run/secrets/pinocchio/profiles.yaml`
- `/run/secrets/pinocchio/config.yaml`

### Public route contract

The K3s ingress should serve:

- `/`
- `/healthz`
- `/auth/login`
- `/auth/callback`
- `/auth/logout`
- `/auth/logout/callback`
- `/chat`
- `/ws`
- `/api/timeline`

## Design Decisions

### Decision 1: Do not preserve the old AppRole bootstrap inside K3s

The old hosted environment needed AppRole because the app was running outside Kubernetes. Inside K3s, that indirection is unnecessary for the first migration path. We already built VSO specifically so workloads can receive Kubernetes-native secret material from Vault.

### Decision 2: Keep external dependencies external for the first migration

We should not combine "first app migration" with:

- Keycloak migration
- MySQL platform migration
- image-registry architecture cleanup

Those are valid future tickets, but they would create too much blast radius here.

### Decision 3: Accept a bootstrap image-import exception

The current blocker to a perfectly clean GitOps story is image distribution, not application config. There is no ready registry path for the private CoinVault image in this ticket yet. For the first migration, a documented image import onto the single K3s node is acceptable as a bootstrap exception. The desired long-term state is a proper registry/publish path.

## Alternatives Considered

### Alternative 1: Migrate hair-booking first

Rejected because the runtime is not yet concrete enough to become a real hosted workload in this ticket.

### Alternative 2: Keep CoinVault on AppRole inside K3s

Rejected because it would copy an off-cluster auth pattern into a cluster that already has a better mechanism.

### Alternative 3: Delay the first app migration until cluster-level MySQL exists

Rejected for now because the current external MySQL dependency is already known and reachable, while the point of this ticket is to prove application migration, not data-platform migration.

## Implementation Plan

1. Record the app choice and runtime contract.
2. Add CoinVault-specific Vault policy and Kubernetes role bindings.
3. Add the Argo CD application and local Kustomize package.
4. Add VSO objects for runtime env and Pinocchio config.
5. Add deployment, service, ingress, and PVC manifests.
6. Seed or copy the required Vault secrets into the K3s Vault.
7. Update external Keycloak redirect URIs for the K3s hostname.
8. Build and import the app image onto the node.
9. Deploy through Argo CD.
10. Validate health, auth, and secret consumption.

## Open Questions

- Should the first K3s hostname be `coinvault.yolo.scapegoat.dev` or another parallel subdomain?
- How long should the image-import exception remain before we require registry-backed delivery?
- Should the runtime secret in K3s preserve exactly the old key names, or should it be normalized for direct env consumption later?

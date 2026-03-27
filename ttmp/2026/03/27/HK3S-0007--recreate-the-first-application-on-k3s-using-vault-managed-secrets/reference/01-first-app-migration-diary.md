---
Title: First app migration diary
Ticket: HK3S-0007
Status: active
Topics:
    - vault
    - k3s
    - migration
    - gitops
    - applications
DocType: reference
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: Chronological diary for choosing and implementing the first real application migration onto K3s using Vault-managed secrets.
LastUpdated: 2026-03-27T16:05:00-04:00
WhatFor: Use this to review the exact decisions, commands, and reasoning behind the first real application migration after the Vault platform work.
WhenToUse: Read this when continuing or reviewing HK3S-0007.
---

# First app migration diary

## Goal

Choose the first real application to deploy on K3s using the new Vault plus VSO platform path, then document and execute that migration with enough detail that the next app migration is easier.

## Step 1: Compare candidates and choose the first app based on deployability, not just secret simplicity

I started HK3S-0007 by revisiting the candidate list from the earlier platform design. The original tension was straightforward: hair-booking had the simpler secret story, while CoinVault had the richer existing hosted runtime contract. At the platform-design stage that was still an open question. For actual implementation, I needed to answer a stricter question: which app can be recreated as a real K3s workload now, not just theoretically later.

I re-read the current HK3S-0007 ticket, the earlier migration design ticket, the hair-booking Vault SES handoff, and the current CoinVault deployment contract. That comparison changed the framing. Hair-booking does have a narrow Vault policy and a very simple secret path at `kv/apps/hair-booking/prod/ses`, but the repository itself is not yet a real hosted service contract. It has no meaningful K8s packaging, no actual runtime deployment documentation, and no obvious backend container entrypoint to move. It is a simpler secret integration, but not a simpler application migration.

CoinVault is the opposite. It has more moving parts, but it is a real deployable service today:

- a Dockerfile
- a hosted runtime contract
- a health check
- a public route surface
- an existing Keycloak OIDC integration
- an existing Vault-backed runtime contract
- a known MySQL dependency and local SQLite persistence paths

That made the decision much clearer. For the first K3s migration ticket, the right criterion is "smallest realistic end-to-end hosted workload," not "smallest isolated secret."

### What I did
- Read the HK3S-0007 index, plan, and tasks.
- Re-read the earlier platform design and migration guidance from HK3S-0002.
- Read the hair-booking SES/Vault handoff document and current least-privilege policy.
- Read the CoinVault Coolify deployment contract, hosted operations playbook, Dockerfile, runtime bootstrap code, and entrypoint.
- Confirmed the live K3s cluster already has the platform layers this app needs:
  - Vault
  - Vault Kubernetes auth
  - Vault Secrets Operator

### Why
- The first migration needs to end in a live workload. A simpler secret contract is not enough if the app itself is not ready to host.

### What worked
- The comparison produced a decisive answer instead of another round of ambiguous “maybe later” analysis.
- CoinVault’s existing docs are strong enough that I can translate them into K3s primitives rather than inventing a deployment from scratch.

### What didn't work
- I initially expected hair-booking to remain the favorite because of its smaller Vault surface. Once I looked at the repo shape, that assumption did not hold up.
- My first `docmgr doc add` attempt used `--type` instead of `--doc-type`, which failed with `unknown flag: --type`.

### What I learned
- The right first migration target is the simplest *deployable* app, not the simplest *secret path*.
- CoinVault can likely run on K3s without its old AppRole bootstrap path if VSO provides the runtime env values and the Pinocchio YAML as Kubernetes-native inputs.

### What was tricky to build
- The trickiest part was not the tech; it was being honest about the decision criteria. Hair-booking is the cleaner secret example, but not the cleaner first hosted migration.

### What warrants a second pair of eyes
- Review the decision criteria before the live deploy work goes further: if someone strongly prefers a purely lower-risk secret demo, that should be a separate ticket, not this “first real application” ticket.

### What should be done in the future
- Write the runtime contract for CoinVault on K3s, then scaffold the Argo app, VSO resources, and deployment manifests.

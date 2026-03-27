---
Title: Deploy Hetzner K3s Demo
Ticket: HK3S-0001
Status: active
Topics:
    - infra
    - kubernetes
    - terraform
    - gitops
DocType: index
Intent: long-term
Owners: []
RelatedFiles:
    - Path: README.md
      Note: Primary description of the stack and operator flow
    - Path: cloud-init.yaml.tftpl
      Note: Bootstrap sequence for K3s
    - Path: main.tf
      Note: Hetzner resources and cloud-init wiring
    - Path: terraform.tfvars.example
      Note: Example operator values for first apply
    - Path: variables.tf
      Note: Required deployment inputs and defaults
ExternalSources: []
Summary: ""
LastUpdated: 2026-03-27T07:57:21.511808165-04:00
WhatFor: Guided deployment of this repo's single-node K3s demo stack to Hetzner with tracked steps, operator inputs, and validation notes.
WhenToUse: Use this ticket as the control point while preparing, deploying, validating, and documenting the Hetzner environment.
---


# Deploy Hetzner K3s Demo

## Overview

This ticket turns the repository into an operator-driven deployment workflow for a single-node Hetzner K3s environment. The repo already contains the infrastructure and bootstrap logic; the remaining work is to collect environment-specific inputs, run the provisioning steps in order, and record outcomes as we go.

The deployment will be tracked in small, reviewable steps. Each completed step should update the diary, the task list, and git history so the state of the rollout stays reconstructable.

## Current Step

Step 3 is active but blocked: choose an orderable Hetzner server type or location, then re-run `terraform apply`.

## Key Links

- [Deployment Plan](./design-doc/01-deployment-plan.md)
- [Deployment Runbook](./playbook/01-deployment-runbook.md)
- [Diary](./reference/01-diary.md)
- [Tasks](./tasks.md)
- [Changelog](./changelog.md)

## Status

Current status: **active**

Blocking external inputs:

- Replacement for `cpx31` in `fsn1`, or confirmation to keep `cpx31` and switch location

Inputs already resolved or proposed:

- SSH public key path: `~/.ssh/id_ed25519.pub`
- Confirmed `admin_cidrs`: `98.175.153.62/32`
- Confirmed repo URL candidate: `https://github.com/wesen/2026-03-27--hetzner-k3s.git`
- Git revision: `main`
- Server type override: `cpx31`
- Confirmed hostname: `k3s.scapegoat.dev`
- Confirmed ACME email: `wesen@ruinwesen.com`
- Local `terraform.tfvars` created and excluded from git
- `terraform init` completed successfully
- `terraform validate` completed successfully
- `terraform apply` created the firewall and updated the existing SSH key name, but server creation failed because `cpx31` is unavailable in `fsn1`

Closest orderable alternatives discovered:

- `cpx32` in `fsn1` for 11.99/month
- `cpx42` in `fsn1` for 21.99/month
- keep `cpx31` and move location to `nbg1` or `hel1` for 14.99/month

## Topics

- infra
- kubernetes
- terraform
- gitops

## Tasks

See [tasks.md](./tasks.md) for the current task list.

## Changelog

See [changelog.md](./changelog.md) for recent changes and decisions.

## Structure

- design-doc/ - Architecture and rollout planning documents
- reference/ - Prompt packs, API contracts, context summaries
- playbook/ - Command sequences and operational procedures
- scripts/ - Temporary code and tooling
- various/ - Working notes and research
- archive/ - Deprecated or reference-only artifacts

---
Title: Deployment Plan
Ticket: HK3S-0001
Status: active
Topics:
    - infra
    - kubernetes
    - terraform
    - gitops
DocType: design-doc
Intent: long-term
Owners: []
RelatedFiles:
    - Path: README.md
      Note: Overall deployment architecture and bootstrap order
    - Path: cloud-init.yaml.tftpl
      Note: Bootstraps cluster services and Argo CD application
    - Path: main.tf
      Note: Connects Terraform inputs to Hetzner resources and cloud-init
    - Path: variables.tf
      Note: Defines required and optional deployment inputs
ExternalSources: []
Summary: Step-by-step plan for deploying this single-node Hetzner K3s demo stack.
LastUpdated: 2026-03-27T07:57:29.538440895-04:00
WhatFor: Explain how this repo should be deployed to Hetzner and what decisions or operator inputs are required before running Terraform.
WhenToUse: Read before executing the runbook so the deployment order, defaults, and open questions are explicit.
---


# Deployment Plan

## Executive Summary

This repo is already structured to provision a single Hetzner Cloud VM, bootstrap K3s and Argo CD with cloud-init, and deploy the demo stack from Git. The deployment work is therefore mostly about providing correct environment-specific values and executing the bootstrap in the right order.

The plan is to use the repo as-is, document each operational step in this ticket, and checkpoint the work in git as we go. The main external dependencies are Hetzner credentials, DNS ownership, a reachable Git repo, and a small set of secret values.

## Problem Statement

The infrastructure code is ready to run, but it is not yet tied to a specific Hetzner account, domain, SSH key, or Git remote. Without a tracked operator workflow, those missing values are easy to lose, and validation steps can be skipped or repeated inconsistently.

## Proposed Solution

Create a dedicated deployment ticket that acts as the control plane for the rollout:

1. Capture the current step, operator questions, and deployment assumptions.
2. Maintain a runbook with the exact command sequence.
3. Record each completed step in the diary and changelog.
4. Keep git commits incremental so repo state matches the documented progress.

Operationally, the deployment flow is:

1. Confirm external inputs and whether defaults stay unchanged.
2. Populate `terraform.tfvars` locally.
3. Provision the server with Terraform.
4. Point DNS at the new server IP.
5. Wait for cloud-init to finish K3s, cert-manager, Argo CD, image import, and Argo CD application bootstrap.
6. Fetch kubeconfig and validate cluster, Argo CD, and app reachability.

## Design Decisions

- Use a single docmgr ticket as the deployment journal so the operational state stays attached to the repo.
- Keep the repo's default single-node architecture rather than redesigning the stack before first deployment.
- Assume the simplest supported path first: a public Git repo that Argo CD can read without extra repo credentials.
- Ask for blocking operator inputs only when they cannot be inferred locally from repository defaults.
- Commit progress in small checkpoints so the written diary and repository history stay aligned.

## Alternatives Considered

- Ad-hoc deployment in the shell without ticket documentation.
  Rejected because the user explicitly wants a tracked, step-by-step workflow with diary updates.
- Refactoring the stack before first deployment.
  Rejected because there is no evidence yet that the current Terraform or bootstrap path is broken; the fastest route is to validate the existing design first.
- Designing around a private Git repo immediately.
  Rejected for now because the repository README already states that a public repo is the easiest bootstrap path.

## Implementation Plan

1. Create the deployment ticket, runbook, diary, task list, and git checkpoint.
2. Confirm the required external values:
   - Hetzner API token handling
   - SSH public key
   - admin CIDR list
   - repo URL and revision
   - base domain and ACME email
   - PostgreSQL password
3. Prepare the local `terraform.tfvars`.
4. Run Terraform to provision the Hetzner VM, firewall, and SSH key resource.
5. Update DNS so `demo.<base_domain>` resolves to the server IPv4.
6. Watch cloud-init finish bootstrap on the node.
7. Fetch kubeconfig and validate:
   - node Ready
   - Argo CD application Healthy/Synced
   - HTTPS working for the demo app
8. Record final outputs, caveats, and any follow-up improvements.

## Open Questions

- Which Git repository URL should cloud-init clone and Argo CD watch?
- Which branch/tag/commit should be deployed?
- Which SSH public key should be uploaded to Hetzner?
- Which admin CIDR(s) should be allowed for SSH and optional Kubernetes API access?
- Which base domain and ACME email should be used?
- Should the ACME server remain production or switch to Let's Encrypt staging for the first pass?
- What PostgreSQL password should be injected into the Kubernetes secret?
- Do we want to keep the infrastructure defaults for `server_type`, `location`, and `server_name`?

## References

- [README](../../../../../../README.md)
- [Deployment Runbook](../playbook/01-deployment-runbook.md)
- [Diary](../reference/01-diary.md)

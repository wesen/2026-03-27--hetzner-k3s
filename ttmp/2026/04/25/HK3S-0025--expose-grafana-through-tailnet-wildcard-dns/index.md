---
Title: Expose Grafana through dedicated tailnet DNS
Ticket: HK3S-0025
Status: active
Topics:
    - tailscale
    - dns
    - grafana
    - observability
    - gitops
    - argocd
    - k3s
    - terraform
DocType: index
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: "Plan and phased task list for exposing Grafana as grafana.tail.scapegoat.dev via Tailscale Kubernetes Operator and Terraform-managed dedicated DNS records."
LastUpdated: 2026-04-25T11:15:59.815546372-04:00
WhatFor: "Track the operator-first private Grafana access implementation using dedicated tailnet DNS records rather than a wildcard reverse proxy."
WhenToUse: "Use when implementing or reviewing the Tailscale Operator and Terraform DNS work for grafana.tail.scapegoat.dev."
---

# Expose Grafana through dedicated tailnet DNS

## Overview

<!-- Provide a brief overview of the ticket, its goals, and current status -->

## Key Links

- **Related Files**: See frontmatter RelatedFiles field
- **External Sources**: See frontmatter ExternalSources field

## Status

Current status: **active**

## Topics

- tailscale
- dns
- grafana
- observability
- gitops
- argocd
- k3s
- terraform

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

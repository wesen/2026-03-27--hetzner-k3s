---
Title: Install Tailscale for stable cluster admin access
Ticket: HK3S-0018
Status: active
Topics:
    - k3s
    - networking
    - tailscale
    - ssh
    - kubectl
    - firewall
DocType: index
Intent: long-term
Owners: []
RelatedFiles:
    - Path: main.tf
      Note: Hetzner firewall and server resource that currently gate SSH and Kubernetes API by public admin CIDRs
    - Path: cloud-init.yaml.tftpl
      Note: Bootstrap path that should be updated after the live Tailscale install is proven
    - Path: docs/hetzner-k3s-server-setup.md
      Note: Main operator guide that should eventually describe the Tailscale-first admin path
ExternalSources: []
Summary: "Install Tailscale on the Hetzner K3s node, move cluster administration to the go-go-golems.org.github tailnet, and backfill the reproducible install path into cloud-init and docs."
LastUpdated: 2026-03-29T20:05:00-04:00
WhatFor: "Use this ticket to stabilize SSH and kubectl access through Tailscale instead of depending on changing public IPs and Hetzner firewall CIDRs."
WhenToUse: "Read this when implementing or reviewing the move from public-IP-based admin access to tailnet-based admin access."
---

# Install Tailscale for stable cluster admin access

## Overview

This ticket exists because the cluster’s current admin access path is fragile:

- SSH on `22` is restricted by Hetzner firewall `admin_cidrs`
- Kubernetes API on `6443` is also restricted by `admin_cidrs`
- when the operator’s public IP changes, `kubectl` and SSH both break even though the apps themselves stay reachable

The intended improvement is:

- install Tailscale on the K3s node
- join it to the `go-go-golems.org.github` tailnet
- use Tailscale IP or MagicDNS for SSH and `kubectl`
- then backfill the stable parts of that setup into `cloud-init`

## Current Step

Step 7 is the current closeout step:

- Tailscale is installed and running on the live Hetzner node
- the node has joined the `go-go-golems.org.github` tailnet
- SSH over the Tailscale path is working
- `kubectl` over the Tailscale path is working
- `cloud-init` and the operator docs are already backfilled
- the remaining decision is whether public `6443` should now be tightened

## Key Links

- Design guide:
  - [01-tailscale-cluster-admin-access-strategy.md](./design-doc/01-tailscale-cluster-admin-access-strategy.md)
- Implementation guide:
  - [01-tailscale-cluster-admin-access-implementation-guide.md](./playbooks/01-tailscale-cluster-admin-access-implementation-guide.md)
- Implementation diary:
  - [01-tailscale-cluster-admin-access-diary.md](./reference/01-tailscale-cluster-admin-access-diary.md)

## Current Decision

Current decision:

- install and join Tailscale manually on the live node first
- only after the live path is proven, backfill the package install and service enablement into `cloud-init`
- do not commit a long-lived Tailscale auth key into generic bootstrap config

Why:

- the live node needs stable admin access now
- bootstrap reproducibility still matters, but it should follow a proven live path
- the Tailscale auth material should not casually end up in Terraform state or generic cloud-init user data unless we deliberately accept that tradeoff

## Live Status

Current live status on the node:

- `tailscale status --json` reports `BackendState = "Running"`
- Tailscale IPv4 is `100.73.36.123`
- MagicDNS name is `k3s-demo-1.tail879302.ts.net`
- K3s `tls-san` now includes both the Tailscale IP and MagicDNS name
- `kubectl` succeeds against the Tailscale-addressed kubeconfig
- public firewall access was temporarily reopened using the current `admin_cidrs` only so this install could proceed

This means the operator path is now proven. The remaining work is policy: whether public `6443` should remain open as a fallback or be tightened now that Tailscale works.

## Tasks

See [tasks.md](./tasks.md) for the live checklist.

## Changelog

See [changelog.md](./changelog.md) for the chronological trail.

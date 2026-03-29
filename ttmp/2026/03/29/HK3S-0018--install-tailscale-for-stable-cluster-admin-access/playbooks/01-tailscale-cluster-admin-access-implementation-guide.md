---
Title: Tailscale cluster admin access implementation guide
Ticket: HK3S-0018
Status: active
Topics:
    - tailscale
    - ssh
    - kubectl
    - firewall
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/cloud-init.yaml.tftpl
      Note: Bootstrap file to backfill after the live install is proven
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/hetzner-k3s-server-setup.md
      Note: Main operator guide that should describe the preferred admin path
ExternalSources: []
Summary: "Detailed implementation guide for installing Tailscale on the K3s node, validating SSH and kubectl over the tailnet, and backfilling the reproducible bootstrap path."
---

# Tailscale cluster admin access implementation guide

## Goal

Stabilize operator access to the cluster by moving SSH and `kubectl` onto Tailscale.

## Step 1: Live install first

Install Tailscale on the existing node first. This is the lowest-risk way to prove:

- package install works
- the node can join the tailnet
- SSH over Tailscale works
- `kubectl` over Tailscale works

Do not start with `cloud-init`.

## Step 2: Join the tailnet

Join the node to:

- `go-go-golems.org.github`

Capture:

- Tailscale IPv4
- Tailscale IPv6 if useful
- MagicDNS hostname if available

Those become the new preferred operator endpoints.

## Step 3: Validate operator paths

Validate:

- `ssh root@<tailscale-name-or-ip>`
- `kubectl --kubeconfig ... get nodes`

The important part is not “does Tailscale show connected.” The important part is whether the real admin workflows work through it.

## Step 4: Update kubeconfig usage

Once the node is reachable on the tailnet, generate or patch a kubeconfig so that:

- the cluster server endpoint points at the Tailscale address

That turns the Kubernetes API path from “public-IP plus firewall whitelist” into “tailnet path.”

## Step 5: Backfill bootstrap

After the live path is proven, update `cloud-init.yaml.tftpl` so future nodes:

- install Tailscale
- enable `tailscaled`

Keep the auth/join step separate unless a deliberate secret-handling decision is made.

## Step 6: Document the new normal

Update the repo docs so that:

- Tailscale is the preferred admin path
- public `6443` is no longer treated as the normal day-2 route
- firewall follow-up decisions are explicit

## Review checklist

The work is ready for review when:

- the node is on the tailnet
- SSH works through Tailscale
- `kubectl` works through Tailscale
- bootstrap docs are updated
- the diary records the exact live access details and any caveats

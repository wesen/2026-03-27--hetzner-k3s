---
Title: Tailscale cluster admin access strategy
Ticket: HK3S-0018
Status: active
Topics:
    - tailscale
    - networking
    - firewall
    - ssh
    - kubectl
DocType: design
Intent: long-term
Owners: []
RelatedFiles:
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/main.tf
      Note: Current public-IP-based admin firewall model
    - Path: /home/manuel/code/wesen/2026-03-27--hetzner-k3s/cloud-init.yaml.tftpl
      Note: Bootstrap path to backfill after the live install is proven
ExternalSources: []
Summary: "Design guide for moving cluster admin access from changing public IPs to the go-go-golems.org.github Tailscale tailnet."
---

# Tailscale cluster admin access strategy

## Problem

The cluster currently uses Hetzner firewall `admin_cidrs` to protect:

- SSH on port `22`
- Kubernetes API on port `6443`

That works only as long as the operator’s public IP stays stable. In practice it does not, which means normal day-2 operations break whenever the public IP changes.

The visible symptom is:

- apps on `80/443` still work
- but `ssh` and `kubectl` start timing out

That is operationally annoying and unnecessary.

## Proposed solution

Put the Hetzner node on the `go-go-golems.org.github` Tailscale tailnet and make Tailscale the preferred admin path for:

- SSH
- `kubectl`

That changes the model from:

```text
operator laptop public IP
  -> Hetzner firewall admin_cidrs
  -> SSH / kubectl
```

to:

```text
operator device on tailnet
  -> Tailscale overlay
  -> node tailnet IP or MagicDNS name
  -> SSH / kubectl
```

## Why Tailscale is the right fit here

- the user already has a real tailnet to join: `go-go-golems.org.github`
- the problem is human/admin connectivity, not service ingress
- Tailscale solves the moving-public-IP problem directly
- it lets us reduce dependence on public `6443`

## Why manual install first

For the current live server, the right order is:

1. install and join Tailscale manually
2. confirm that SSH and `kubectl` work through the tailnet
3. only then backfill the reproducible install pieces into `cloud-init`

This is better than editing bootstrap first because:

- the live node needs the fix now
- it is easier to debug one live install than a full first-boot path
- auth-key handling is a separate decision from package install

## Why not put the auth key straight into cloud-init

Because then the join credential likely ends up in places we should be deliberate about:

- Terraform state
- rendered cloud-init user data
- Hetzner metadata history

That might still be acceptable one day if we choose an ephemeral auth-key model very intentionally, but it should not happen by accident.

## Implementation boundary

This ticket should backfill into `cloud-init` only the stable, low-risk parts:

- install Tailscale package
- enable `tailscaled`

The join step can stay:

- manual, or
- secret-driven through a later dedicated bootstrap mechanism

## Success criteria

The ticket is successful when:

- the node is visible on the `go-go-golems.org.github` tailnet
- SSH works over Tailscale
- `kubectl` works over Tailscale
- the preferred admin path in docs is Tailscale-first
- the repo bootstrap path includes Tailscale install and daemon enablement

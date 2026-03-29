# Changelog

## 2026-03-29

- Initial workspace created
- Defined the access problem as unstable public-IP-based SSH and Kubernetes API reachability
- Chose Tailscale on the `go-go-golems.org.github` tailnet as the preferred operator path
- Added the ticket docs, implementation guide, tasks, and diary before touching the live node
- Restored public admin access temporarily by reapplying the Hetzner firewall with the current operator public IP in local `admin_cidrs`
- Installed Tailscale on the live node and enabled `tailscaled`
- Confirmed the node first reached `NeedsLogin` and captured the live auth URL
- Added replayable operator scripts under the ticket `scripts/` directory
- Backfilled Tailscale package installation and `tailscaled` enablement into `cloud-init`
- Updated the main Hetzner/K3s setup guide to describe Tailscale as the preferred admin access path
- Joined the node to the `go-go-golems.org.github` tailnet after approval
- Captured the live Tailscale IPv4 and MagicDNS name
- Validated SSH over the Tailscale path
- Fixed the Kubernetes API certificate mismatch by adding Tailscale `tls-san` entries to K3s
- Validated `kubectl` over a Tailscale-addressed kubeconfig
- Disabled the public Kubernetes API firewall rule on `6443` after proving the Tailscale path
- Verified that `kubectl` still worked over Tailscale and that direct public `6443` access timed out

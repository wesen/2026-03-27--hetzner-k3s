---
Title: Tailscale cluster admin access diary
Ticket: HK3S-0018
Status: complete
Topics:
    - tailscale
    - ssh
    - kubectl
    - firewall
DocType: reference
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: "Chronological diary for installing Tailscale on the Hetzner K3s node and moving cluster admin access onto the tailnet."
LastUpdated: 2026-03-29T20:35:00-04:00
WhatFor: "Use this to continue or review the exact implementation trail for HK3S-0018."
WhenToUse: "Read this when continuing the Tailscale access work or documenting the final operator path."
---

# Tailscale cluster admin access diary

## Goal

Replace the fragile public-IP-based admin path with stable Tailscale-based access for:

- SSH
- `kubectl`

## Step 1: Turn the access problem into a dedicated networking ticket

The immediate trigger for this ticket was that `kubectl` access had become unreliable again once the public source IP changed. Public app ingress was still working, but the admin paths were not. That is exactly the kind of problem Tailscale is meant to remove.

The correct scope here is not “just install a package.” The real change is:

- change the preferred admin network path for this cluster
- then backfill the reproducible part into bootstrap

So I opened HK3S-0018 with a design guide, implementation guide, tasks, and diary before touching the live node.

### What I did
- Defined the problem as unstable admin access due to `admin_cidrs`.
- Chose the `go-go-golems.org.github` tailnet as the target admin network.
- Documented the decision to prove the live manual install before editing `cloud-init`.

### Why
- This is a platform access change, not just a package-install chore.

### What worked
- The scope became clear immediately once framed as “preferred admin path” instead of “maybe install tailscale.”

### What didn't work
- Nothing failed yet; this was the scoping slice.

### What I learned
- The right split is manual live join first, bootstrap backfill second.

### What should be done in the future
- Install Tailscale on the live node next and capture the actual Tailscale endpoint details before any bootstrap edits.

## Step 2: Re-open public admin access just enough to install Tailscale

Before I could install Tailscale, I had to restore public admin access. The Hetzner firewall had drifted back to the wrong source IP again, so SSH and `kubectl` were timing out even though the public apps still worked.

### What I did
- Checked the current public IPv4 from the operator machine.
- Compared it to the `admin_cidrs` currently being applied from local Terraform inputs.
- Updated local `terraform.tfvars` to restore the current public IP as the allowed admin CIDR.
- Applied only the Hetzner firewall target to reopen ports `22` and `6443`.

### Why
- Tailscale installation needed a live SSH path first.
- This was a tactical recovery step, not the intended long-term solution.

### What worked
- Targeted firewall apply was enough to restore SSH without changing unrelated infrastructure.

### What didn't work
- The public-IP-based admin model failed again exactly the way this ticket is meant to prevent.

### What I learned
- Tailscale is not just a convenience here. It is the correct fix for a recurring operator-path failure mode.

### What should be done in the future
- Once Tailscale is stable, decide whether public `6443` should remain exposed at all.

## Step 3: Install Tailscale on the live node and observe the auth boundary

With SSH working again, I installed Tailscale on the Hetzner node and started `tailscaled`. The package install and daemon startup both worked immediately.

### What I did
- Ran the live install over SSH using the Tailscale install script.
- Enabled and started `tailscaled`.
- Ran `tailscale up --accept-routes=false --accept-dns=true --ssh`.
- Captured the resulting auth URL.
- Added ticket-local replay scripts:
  - `scripts/01-install-tailscale-on-live-node.sh`
  - `scripts/02-check-tailscale-status.sh`
  - `scripts/03-get-tailscale-ip.sh`

### Why
- This proves the live node can run Tailscale before we rely on it as the preferred admin path.

### What worked
- Package install completed cleanly.
- `tailscaled` started cleanly.
- `tailscale up` produced the expected login URL and left the node in a recoverable `NeedsLogin` state instead of failing ambiguously.

### What didn't work
- The node has not yet joined the tailnet because approval has not been completed in the browser.

### Exact live state
- `tailscale status --json` currently reports:
  - `BackendState = "NeedsLogin"`
  - `AuthURL = "https://login.tailscale.com/a/c4c195b01b072"`

### What I learned
- The main blocker is no longer package installation or service wiring.
- The remaining step is explicit human authorization of the node into `go-go-golems.org.github`.

### What should be done in the future
- After approval, capture the Tailscale IP or MagicDNS name immediately and validate both SSH and `kubectl` through that path before tightening the public firewall.

## Step 4: Backfill the reproducible install path into bootstrap and docs

While waiting for tailnet approval, I backfilled the non-secret installation steps into bootstrap and the main server-setup guide.

### What I did
- Updated `cloud-init.yaml.tftpl` to:
  - add the Tailscale package repository
  - install `tailscale`
  - enable and start `tailscaled`
  - intentionally avoid running `tailscale up`
- Updated `docs/hetzner-k3s-server-setup.md` to explain:
  - Tailscale is now the preferred long-term operator access path
  - `admin_cidrs` is still needed as a fallback/bootstrap path
  - public `22` and `6443` failures are often just stale firewall CIDRs

### Why
- Future nodes should at least come up with the daemon ready, even if join remains a deliberate operator step.

### What worked
- This keeps the bootstrap path reproducible without baking a reusable tailnet auth secret into generic cloud-init.

### What didn't work
- Bootstrap still carries a lot of legacy demo-stack assumptions; this change only touches the Tailscale part, not the whole bootstrap design.

### What I learned
- The right compromise is “install in cloud-init, join outside cloud-init” until we deliberately design a secret-driven join flow.

### What should be done in the future
- Revisit whether a secret-driven Tailscale auth-key join belongs in a later, more opinionated platform bootstrap design.

## Step 5: Approve the node, then fix Kubernetes API TLS for the tailnet path

Once the node was approved into the tailnet, SSH over the Tailscale IPv4 worked immediately. The first `kubectl` attempt did not.

### What I did
- Re-ran `tailscale status --json` and confirmed the node had joined the `go-go-golems.org.github` tailnet.
- Captured:
  - Tailscale IPv4: `100.73.36.123`
  - MagicDNS name: `k3s-demo-1.tail879302.ts.net`
- Validated SSH over Tailscale using `root@100.73.36.123`.
- Fetched a kubeconfig that pointed at `https://100.73.36.123:6443`.
- Observed TLS verification failure from `kubectl`.
- Inspected `/etc/rancher/k3s/config.yaml` and confirmed it only contained `write-kubeconfig-mode`.
- Added `tls-san` entries for:
  - `100.73.36.123`
  - `k3s-demo-1.tail879302.ts.net`
- Restarted `k3s` and waited for the node to become `Ready`.
- Re-fetched the kubeconfig and re-ran:
  - `kubectl get nodes -o wide`
  - `kubectl -n argocd get applications`
- Added the replayable operator script:
  - `scripts/04-configure-k3s-tailscale-tls-san.sh`

### Why
- Tailscale networking alone is not enough. The Kubernetes API certificate also has to present SANs that match the Tailscale endpoint we want operators to use.

### What worked
- SSH over the Tailscale IP worked as soon as the node joined the tailnet.
- K3s picked up the `tls-san` changes cleanly after restart.
- `kubectl` succeeded end to end over the Tailscale-addressed kubeconfig after the SAN fix.

### What didn't work
- The first kubeconfig attempt failed with the expected certificate mismatch:
  - certificate valid for `10.43.0.1`, `127.0.0.1`, `2a01:4f8:c013:c4d6::1`, `91.98.46.169`, `::1`
  - not valid for `100.73.36.123`

### Exact live state
- `tailscale status --json` now reports `BackendState = "Running"`
- node DNS name: `k3s-demo-1.tail879302.ts.net.`
- operator path proven:
  - `ssh root@100.73.36.123`
  - `KUBECONFIG=... kubectl get nodes -o wide`
  - `KUBECONFIG=... kubectl -n argocd get applications`

### What I learned
- The correct operator sequence is:
  1. install Tailscale
  2. approve node
  3. capture Tailscale IP and DNS name
  4. add `tls-san` entries to K3s
  5. restart K3s
  6. fetch a Tailscale-addressed kubeconfig

### What should be done in the future
- Decide whether the public `6443` exposure can now be tightened, since the Tailscale path is proven.
- Decide whether a future bootstrap or post-join automation path should update `tls-san` automatically after node join.

## Step 6: Tighten the public firewall after proving the Tailscale admin path

Once SSH and `kubectl` were both proven over the tailnet, I made the policy choice that had been intentionally deferred earlier in the ticket.

### What I did
- Decided to keep public SSH on `22` restricted by `admin_cidrs` as a fallback path.
- Decided to disable the public Kubernetes API path on `6443`.
- Updated local `terraform.tfvars` for the live environment to set:
  - `allow_kube_api = false`
- Applied only the Hetzner firewall change with:
  - `terraform apply -target=hcloud_firewall.default -auto-approve`
- Re-validated:
  - `kubectl` over the Tailscale kubeconfig still works
  - key Argo applications are still `Synced Healthy`
  - direct socket connection to `91.98.46.169:6443` now times out

### Why
- Tailscale is now the stable operator path.
- Leaving public `6443` open would preserve the old exposure without enough benefit.
- Keeping public `22` narrow is still useful as a recovery fallback while Tailscale remains the preferred day-2 path.

### What worked
- The firewall update removed only the `6443` rule.
- Tailscale-based `kubectl` continued to work immediately after the change.
- The public API path stopped answering as intended.

### What didn't work
- Nothing failed technically in this tightening slice.

### What I learned
- The right end state for this cluster is not “no public admin access at all.”
- The right end state is:
  - narrow public SSH fallback
  - no public Kubernetes API
  - Tailscale for routine operator access

### What should be done in the future
- If Tailscale becomes operationally routine enough, revisit whether public `22` should also be tightened further or removed.

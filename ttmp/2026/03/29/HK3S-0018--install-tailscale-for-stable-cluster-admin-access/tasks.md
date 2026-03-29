# Tasks

## Phase 1: Scope and access model

- [x] Define the problem as unstable public-IP-based admin access for SSH and Kubernetes API
- [x] Decide to use the `go-go-golems.org.github` tailnet for stable operator access
- [x] Decide to prove the live manual install first, then backfill reproducible parts into `cloud-init`

## Phase 2: Ticket documentation

- [x] Add the ticket index, design guide, implementation guide, diary, and task list
- [x] Keep the diary updated as implementation proceeds
- [x] Add replayable operator scripts under the ticket `scripts/` directory where that helps traceability

## Phase 3: Live Tailscale install

- [x] Install Tailscale on the Hetzner node
- [x] Enable and start `tailscaled`
- [x] Join the node to the `go-go-golems.org.github` tailnet
- [x] Capture the Tailscale IP and/or MagicDNS hostname
- [x] Validate SSH over Tailscale
- [x] Validate Kubernetes API reachability over Tailscale

## Phase 4: Operator access cutover

- [x] Fetch or generate a kubeconfig that points at the Tailscale address instead of the public IPv4
- [x] Validate `kubectl` end to end using the Tailscale path
- [ ] Decide whether the public `6443` path should remain enabled temporarily or be tightened later

## Phase 5: Bootstrap backfill

- [x] Update `cloud-init.yaml.tftpl` to install Tailscale and enable `tailscaled`
- [x] Document the intentionally manual or secret-driven join step separately from the generic bootstrap
- [x] Update the server setup docs to make Tailscale the preferred admin path

## Phase 6: Firewall follow-up

- [ ] Decide whether to keep SSH on public `22` restricted by `admin_cidrs`, relax it, or eventually rely on Tailscale-only access
- [ ] Decide whether `allow_kube_api` should remain exposed on public `6443` once Tailscale access is stable
- [ ] If appropriate, apply the firewall tightening as a separate deliberate change

## Phase 7: Closeout

- [x] Update the diary, changelog, and ticket index with the final live state
- [x] Commit and push the current Tailscale implementation checkpoint

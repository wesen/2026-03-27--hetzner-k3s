---
Title: "Set Up Tailscale for Stable SSH and kubectl Access"
Slug: "tailscale-k3s-admin-access-playbook"
Short: "Install Tailscale on the Hetzner K3s node, join the go-go-golems.org.github tailnet, and make the Kubernetes API reachable over the tailnet."
Topics:
- tailscale
- k3s
- kubectl
- ssh
- networking
- firewall
Commands:
- ssh
- tailscale
- kubectl
- systemctl
Flags: []
IsTopLevel: true
IsTemplate: false
ShowPerDefault: true
SectionType: Tutorial
---

## What This Page Covers

This page explains how to make cluster administration stable by moving SSH and `kubectl` off the fragile public-IP path and onto Tailscale. It is written for this repository’s actual platform shape: one Hetzner VM, one K3s control plane, a Hetzner firewall that gates `22` and `6443` by `admin_cidrs`, and the `go-go-golems.org.github` tailnet.

This matters because the failure mode is subtle: the public apps can keep working on `80/443` while `ssh` and `kubectl` suddenly time out. That is not an application outage. It is usually just the operator’s source IP drifting away from the firewall CIDR.

The goal of this playbook is to replace that brittle operator path with a stable one:

- install Tailscale on the node
- join the node to the tailnet
- validate SSH over the Tailscale IP or MagicDNS name
- teach K3s to present the Kubernetes API certificate for the Tailscale endpoint
- fetch a Tailscale-based kubeconfig
- optionally tighten public `6443` later

## Architecture

The relevant operator path looks like this:

```text
Laptop
  -> Tailscale client on go-go-golems.org.github
  -> node Tailscale IP / MagicDNS name
  -> SSH on the tailnet
  -> Kubernetes API on 6443 over the tailnet

Hetzner public IP
  -> still serves ingress traffic on 80/443
  -> may still temporarily serve 22/6443 during migration
```

The important distinction is:

- public ingress is for users
- Tailscale is for operators

Do not confuse “app is reachable” with “admin path is healthy.”

## What Lives Where

- [`cloud-init.yaml.tftpl`](../cloud-init.yaml.tftpl)
  - installs Tailscale and enables `tailscaled`
  - intentionally does not run `tailscale up`
- [`docs/hetzner-k3s-server-setup.md`](./hetzner-k3s-server-setup.md)
  - general platform bring-up guide
- [HK3S-0018 index](../ttmp/2026/03/29/HK3S-0018--install-tailscale-for-stable-cluster-admin-access/index.md)
  - detailed ticket history for the live rollout
- [HK3S-0018 scripts](../ttmp/2026/03/29/HK3S-0018--install-tailscale-for-stable-cluster-admin-access/scripts)
  - replayable operator helpers used during the rollout

## Preconditions

Before starting, make sure all of the following are true:

- you can still reach the node somehow
  - either via the current public admin firewall path
  - or via console / rescue access
- the node is supposed to join `go-go-golems.org.github`
- your operator machine is already on that tailnet
- you are comfortable making a brief K3s restart after adding `tls-san`

If public `ssh` is failing before Tailscale is installed, the quick diagnosis is:

```bash
curl -4 https://ifconfig.me
terraform state show hcloud_firewall.default
```

If the current public IP does not match `admin_cidrs`, update `terraform.tfvars` locally and run:

```bash
terraform apply -target=hcloud_firewall.default -auto-approve
```

That is a tactical recovery step only. The long-term goal is to stop depending on that path for routine operations.

## Step 1: Install Tailscale on the Live Node

The live node must have the package and the daemon first. The repository now backfills these steps into `cloud-init`, but for an already-running node you still need to do the first join manually.

Ticket-local replay script:

```bash
bash ttmp/2026/03/29/HK3S-0018--install-tailscale-for-stable-cluster-admin-access/scripts/01-install-tailscale-on-live-node.sh
```

Equivalent manual command:

```bash
ssh root@<public-server-ip> '
  curl -fsSL https://tailscale.com/install.sh | sh &&
  systemctl enable --now tailscaled &&
  tailscale up --accept-routes=false --accept-dns=true --ssh
'
```

Expected result:

- package install completes
- `tailscaled` starts
- `tailscale up` prints an auth URL

If the node is not yet approved, `tailscale status --json` will show:

```text
BackendState = "NeedsLogin"
```

## Step 2: Approve the Node in the Tailnet

Open the URL from `tailscale up` and approve the node into `go-go-golems.org.github`.

Once approval is complete, verify the live state:

```bash
bash ttmp/2026/03/29/HK3S-0018--install-tailscale-for-stable-cluster-admin-access/scripts/02-check-tailscale-status.sh
```

You want to see:

- `BackendState = "Running"`
- a Tailscale IPv4
- a MagicDNS suffix
- the node DNS name

Get the node Tailscale IP directly:

```bash
bash ttmp/2026/03/29/HK3S-0018--install-tailscale-for-stable-cluster-admin-access/scripts/03-get-tailscale-ip.sh
```

In the live rollout, those values were:

- Tailscale IPv4: `100.73.36.123`
- MagicDNS name: `k3s-demo-1.tail879302.ts.net`

## Step 3: Validate SSH Over Tailscale

Once the node is on the tailnet, validate the admin path before touching Kubernetes.

```bash
ssh -o StrictHostKeyChecking=accept-new root@<tailscale-ip> 'hostname && tailscale ip -4 && whoami'
```

Why this matters:

- it proves basic reachability over the tailnet
- it distinguishes “Tailscale join failed” from “Kubernetes certificate issue”

Expected output shape:

```text
k3s-demo-1
100.73.36.123
root
```

## Step 4: Add the Tailscale Endpoint to K3s `tls-san`

This is the step that is easy to miss.

If you fetch a kubeconfig that points at the Tailscale IP immediately after join, `kubectl` will usually fail with an error like:

```text
tls: failed to verify certificate: x509: certificate is valid for ...
not <tailscale-ip>
```

That happens because the kube-apiserver certificate still only knows about:

- `127.0.0.1`
- the cluster IP
- the public IPv4 / IPv6

It does not yet know about the Tailscale IP or the MagicDNS name.

The fix is to add both as `tls-san` entries in `/etc/rancher/k3s/config.yaml`.

Ticket-local replay script:

```bash
bash ttmp/2026/03/29/HK3S-0018--install-tailscale-for-stable-cluster-admin-access/scripts/04-configure-k3s-tailscale-tls-san.sh
```

Equivalent manual file content:

```yaml
write-kubeconfig-mode: "0644"
tls-san:
  - <tailscale-ip>
  - <tailscale-magicdns-name>
```

Then restart K3s and wait for the node to return:

```bash
ssh root@<tailscale-ip> '
  systemctl restart k3s
  until kubectl get nodes >/dev/null 2>&1; do sleep 5; done
  kubectl get nodes -o wide
'
```

Why both values matter:

- the Tailscale IP is the simplest direct operator endpoint
- the MagicDNS name is the cleaner long-term identity if you want host-based access

## Step 5: Fetch a Tailscale-Based kubeconfig

After the SAN fix, fetch a new kubeconfig that points at the Tailscale endpoint:

```bash
./scripts/get-kubeconfig.sh <tailscale-ip>
export KUBECONFIG=$PWD/kubeconfig-<tailscale-ip>.yaml
kubectl get nodes -o wide
kubectl -n argocd get applications
```

This now proves the full operator path:

```text
Laptop -> tailnet -> node -> kube-apiserver -> valid TLS -> kubectl
```

During the live rollout, this validated successfully against:

- `https://100.73.36.123:6443`

and returned the node plus the Argo application list.

## Step 6: Update Bootstrap and Docs

For future nodes, the repo now already backfills the non-secret part of the Tailscale setup into bootstrap:

- Tailscale package install
- `tailscaled` enablement

What is intentionally not automated in generic `cloud-init`:

- `tailscale up`
- any long-lived tailnet auth key

Why:

- reusable auth material should not casually land in Terraform state or Hetzner metadata
- join is still an operator action unless you deliberately design a secret-driven bootstrap path

## Step 7: Decide the Public Firewall Policy

Once Tailscale access is stable, you can decide whether to leave public `6443` in place.

Conservative option:

- keep current `admin_cidrs` firewall rules for a while as fallback
- treat Tailscale as preferred operator path

Stricter option:

- keep public `22` narrow or remove it later
- tighten or disable public `6443`
- rely on Tailscale for daily cluster administration

Recommended sequence:

1. run on Tailscale for a few days
2. confirm `kubectl` and SSH are stable from your actual operator machines
3. only then tighten public `6443`

## Common Failure Modes

### `ssh` and `kubectl` time out, but apps still work

Likely cause:

- stale `admin_cidrs`

Why:

- public ingress on `80/443` is unrelated to the admin firewall on `22/6443`

### Tailscale installed but `tailscale status` says `NeedsLogin`

Likely cause:

- node has not been approved yet

Fix:

- open the auth URL from `tailscale up`

### SSH works over Tailscale but `kubectl` fails TLS verification

Likely cause:

- missing K3s `tls-san` entries for the Tailscale IP / DNS name

Fix:

- update `/etc/rancher/k3s/config.yaml`
- restart K3s
- fetch a fresh kubeconfig

### `kubectl` still points at the public IP

Likely cause:

- operator reused the old kubeconfig

Fix:

- fetch a new kubeconfig and replace `127.0.0.1` with the Tailscale endpoint

## Pseudocode Summary

```text
if public ssh is broken:
  temporarily fix admin_cidrs

install tailscale on node
start tailscaled
run tailscale up
approve node in tailnet

capture tailscale_ip and magicdns_name
verify ssh root@tailscale_ip

update /etc/rancher/k3s/config.yaml:
  keep write-kubeconfig-mode
  add tls-san for tailscale_ip and magicdns_name

restart k3s
wait for node ready

fetch new kubeconfig
replace 127.0.0.1 with tailscale_ip
verify kubectl get nodes
verify kubectl get applications

later:
  decide whether to tighten public 6443
```

## Related Documents

- [docs/hetzner-k3s-server-setup.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/hetzner-k3s-server-setup.md)
- [HK3S-0018 index](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/29/HK3S-0018--install-tailscale-for-stable-cluster-admin-access/index.md)
- [HK3S-0018 implementation guide](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/29/HK3S-0018--install-tailscale-for-stable-cluster-admin-access/playbooks/01-tailscale-cluster-admin-access-implementation-guide.md)

---
Title: Diary
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
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ttmp/2026/04/25/HK3S-0025--expose-grafana-through-tailnet-wildcard-dns/playbook/01-implementation-guide.md
      Note: Detailed implementation guide for option 1 tailnet wildcard DNS and reverse proxy
    - Path: ../terraform/dns/README.md
      Note: Documents that scapegoat.dev DNS is managed in the sibling Terraform repo
    - Path: docs/grafana-keycloak-access-playbook.md
      Note: Existing plan for Grafana Keycloak OIDC once private access path exists
ExternalSources: []
Summary: "Diary for planning option 1: expose Grafana through *.tail.scapegoat.dev using a pragmatic Tailscale-connected reverse proxy and Terraform-managed DNS."
LastUpdated: 2026-04-25T11:25:00-04:00
WhatFor: "Resume HK3S-0025 implementation with context on DNS ownership, namespace naming, and proxy design."
WhenToUse: "Use before implementing tailnet-ingress manifests or modifying ../terraform DNS records."
---

# Diary

## Goal

Record the planning and future implementation of a private tailnet wildcard DNS endpoint for Grafana. This ticket starts with a detailed implementation guide and task list for Option 1: a single Tailscale-connected reverse proxy, not the Tailscale Kubernetes Operator.

## Step 1: Create ticket, tasks, and implementation guide

This step converts the tailnet DNS design discussion into a concrete ticket. The chosen first implementation is a pragmatic tailnet ingress proxy: one Kubernetes package creates a `tailnet-ingress` namespace, runs a Tailscale-connected proxy device, and routes `grafana.tail.scapegoat.dev` to the existing Grafana service in `monitoring`.

The DNS zone is owned outside this repository in the sibling Terraform repo, so the guide explicitly treats DNS as a cross-repo step. The K3s repo will own the Kubernetes proxy and Argo CD Application; `../terraform` will own the `*.tail.scapegoat.dev` wildcard A record.

### Prompt Context

**User prompt (verbatim):** "Let's create a new docmgr ticket + detailed implementation guide and  tasks for option 1. The DNS zone is managed in ../terraform ."

**Assistant interpretation:** Create a new HK3S docmgr ticket, write a detailed implementation playbook for the non-operator tailnet reverse proxy design, and add actionable tasks. Account for DNS being managed by the sibling Terraform repository.

**Inferred user intent:** Prepare an implementation plan that can be executed later without re-litigating namespace names, DNS ownership, Tailscale state, TLS choices, or validation criteria.

**Commit (code):** pending — planning docs and ticket files are created locally before the first documentation commit.

### What I did

- Inspected the sibling Terraform repository and confirmed DNS documentation points at:

  ```text
  /home/manuel/code/wesen/terraform/dns/zones/scapegoat-dev/envs/prod
  ```

- Created ticket `HK3S-0025` titled `Expose Grafana through tailnet wildcard DNS`.
- Created `playbook/01-implementation-guide.md` with:
  - DNS zone naming recommendation: `tail.scapegoat.dev`
  - Kubernetes namespace recommendation: `tailnet-ingress`
  - device name recommendation: `tailnet-ingress-k3s-demo-1`
  - two-phase bootstrap sequence for deploying the Tailscale proxy and then applying Terraform DNS after the stable `100.x` IP is known
  - TLS options, with DNS-01 wildcard certificate as the preferred final state
  - GitOps package layout for `gitops/kustomize/tailnet-ingress/`
  - Terraform DNS record shape for `*.tail.scapegoat.dev`
  - validation and failure-mode sections
- Added tasks covering naming, DNS design, GitOps package creation, TLS, Argo apply, Tailscale IP bootstrap, validation, and documentation.

### Why

- The public Traefik ingress should stay reserved for public applications.
- Observability/admin tools should be reachable through a private tailnet path.
- A wildcard private DNS zone gives stable URLs like `grafana.tail.scapegoat.dev` without exposing Grafana on the public Hetzner IP.
- The first implementation should be debuggable before introducing the Tailscale Kubernetes Operator/Gateway API path.

### What worked

- The existing Terraform repo already documents that `scapegoat.dev` DNS is managed there.
- The implementation naturally splits into two repositories: K3s GitOps for the proxy and Terraform DNS for the wildcard record.

### What didn't work

- The current checked file list under `../terraform/dns` only showed the README at shallow depth. The implementation guide therefore describes the desired Terraform record shape conceptually and instructs the implementer to inspect/create the exact environment files during execution.

### What I learned

- The DNS record cannot be known until the Tailscale proxy has joined the tailnet and received a stable IP, so this must be a two-phase bootstrap.
- Stable Tailscale state is a hard requirement. Without it, every restart can create a new tailnet device/IP and break the wildcard DNS record.

### What was tricky to build

- TLS is the main design fork. The existing cluster issuer uses HTTP-01 through public Traefik, which is not suitable for a private tailnet hostname. The guide therefore treats DNS-01 wildcard TLS as the preferred final state and HTTP over WireGuard only as a temporary MVP.

### What warrants a second pair of eyes

- Review whether public DNS pointing `*.tail.scapegoat.dev` to a `100.x` Tailscale IP is acceptable, or whether this should instead use Tailscale split DNS/private resolver from day one.
- Review the exact Tailscale container mode before implementation: TUN mode with `NET_ADMIN` versus userspace mode plus explicit TCP/HTTP forwarding.

### What should be done in the future

- Implement the guide.
- Consider a future migration from custom proxy to Tailscale Kubernetes Operator once the URL contract and DNS zone are proven.

### Code review instructions

- Start with `playbook/01-implementation-guide.md`.
- Verify the task list in `tasks.md` is actionable and ordered.
- Confirm that no secret values are committed and that all future Tailscale/DNS credentials are routed through Vault/VSO or ignored local Terraform variables.

### Technical details

Default URL contract:

```text
grafana.tail.scapegoat.dev -> Tailscale IP 100.x.y.z -> tailnet-ingress proxy -> monitoring-grafana.monitoring.svc.cluster.local:80
```

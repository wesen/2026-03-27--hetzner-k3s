---
Title: Deployment Runbook
Ticket: HK3S-0001
Status: active
Topics:
    - infra
    - kubernetes
    - terraform
    - gitops
DocType: playbook
Intent: long-term
Owners: []
RelatedFiles:
    - Path: README.md
      Note: Source of the deployment and validation command sequence
    - Path: cloud-init.yaml.tftpl
      Note: Server-side bootstrap actions to monitor and validate
    - Path: scripts/get-kubeconfig.sh
      Note: Helper for fetching a usable kubeconfig from the server
    - Path: terraform.tfvars.example
      Note: Template for the operator-provided Terraform values
ExternalSources: []
Summary: Operator runbook for provisioning, bootstrapping, validating, and troubleshooting the Hetzner deployment.
LastUpdated: 2026-03-27T07:57:29.536346805-04:00
WhatFor: Provide the operator command sequence and checkpoints for deploying this repo to Hetzner.
WhenToUse: Execute this document top to bottom during deployment and update it if the command flow changes.
---


# Deployment Runbook

## Purpose

Provision the Hetzner VM, allow cloud-init to bootstrap K3s and Argo CD, and validate that the demo application is reachable over HTTPS.

## Current Step

Step 13: Argo CD public access is now GitOps-managed at `argocd.yolo.scapegoat.dev`; the next follow-up is to investigate the residual Argo CD `OutOfSync` status and codify the runtime CoreDNS workaround.

## Environment Assumptions

- `terraform`, `ssh`, and `kubectl` are available on the operator machine.
- This repository is available from a Git URL that the Hetzner server can clone.
- The operator controls DNS for the chosen base domain.
- The operator has a Hetzner Cloud API token and an SSH public key.
- The operator can safely store secrets locally in `terraform.tfvars` or provide them another way at apply time.

## Commands

```bash
# 1. Create terraform.tfvars from the example and fill in real values.
cp terraform.tfvars.example terraform.tfvars

# 2. Provision the VM, firewall, and SSH key in Hetzner.
terraform init
terraform apply

# 3. Point DNS at the server once Terraform outputs the public IPv4.
# demo.<base_domain> -> <server IPv4>

# 4. Watch first-boot provisioning.
ssh root@<server-ip> 'tail -f /var/log/cloud-init-output.log'

# 5. Fetch kubeconfig and verify the node.
./scripts/get-kubeconfig.sh <server-ip>
export KUBECONFIG=$PWD/kubeconfig-<server-ip>.yaml
kubectl get nodes

# 6. Check Argo CD bootstrap and log in locally.
kubectl -n argocd get applications
kubectl -n argocd port-forward svc/argocd-server 8080:443

# 7. Get the initial Argo CD admin password.
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

### Required Values Before Step 2

- `hcloud_token`
- `ssh_public_key`
- `admin_cidrs`
- `repo_url`
- `repo_revision` if not `main`
- `base_domain`
- `acme_email`
- `postgres_password`
- Optional override choices:
  - `server_name`
  - `server_type`
  - `location`
  - `app_subdomain`
  - `acme_server`
  - `allow_kube_api`

### Input Notes From Current Discovery

- `repo_url` must be a clone URL the Hetzner server can read non-interactively during cloud-init. The current local Git remote is SSH (`git@github.com:...`), which will not work for bootstrap unless we add credentials on the server. The simplest path is a public HTTPS URL such as `https://github.com/wesen/2026-03-27--hetzner-k3s.git`.
- `base_domain` and `app_subdomain` combine into the final hostname as `<app_subdomain>.<base_domain>`. If the desired hostname is `k3s.scapegoat.com`, use `base_domain = "scapegoat.com"` and `app_subdomain = "k3s"`.
- DNS is configured after Terraform outputs the server IP. The hostname choice should still be decided before apply because it is embedded into the bootstrap manifests.

### Confirmed Values So Far

- `ssh_public_key = ~/.ssh/id_ed25519.pub`
- `admin_cidrs = ["98.175.153.62/32"]`
- `repo_url = "https://github.com/wesen/2026-03-27--hetzner-k3s.git"`
- `repo_revision = "main"`
- `base_domain = "scapegoat.dev"`
- `app_subdomain = "k3s"`
- `argocd_host = "argocd.yolo.scapegoat.dev"`
- `server_type = "cpx32"`
- `acme_email = "wesen@ruinwesen.com"`

### Local Preparation Status

- `terraform.tfvars` has been created locally and is ignored by git.
- `terraform init` succeeded with provider `hetznercloud/hcloud v1.60.1`.
- `terraform validate` succeeded.
- `terraform apply` now succeeded after changing `server_type` to `cpx32`.
- Current server details:
  - IPv4: `91.98.46.169`
  - IPv6: `2a01:4f8:c013:c4d6::1`
  - SSH: `ssh root@91.98.46.169`
  - App URL target: `https://k3s.scapegoat.dev`

### Immediate Next Action

- Optional follow-up: inspect the residual Argo CD drift on `demo-stack-postgres`.
- Optional follow-up: codify the CoreDNS resolver behavior instead of relying on the runtime ConfigMap adjustment.

### Current Runtime Status

- `kubectl get nodes` reports the node as `Ready`.
- The app responds successfully over HTTP when addressed by IP with `Host: k3s.scapegoat.dev`.
- Authoritative DigitalOcean DNS returns:
  - `k3s.scapegoat.dev -> 91.98.46.169`
  - `*.yolo.scapegoat.dev -> 91.98.46.169`
- Public recursive DNS also returns `k3s.scapegoat.dev -> 91.98.46.169`.
- `certificate/demo-app-tls` is `Ready=True`.
- `curl -I https://k3s.scapegoat.dev` returns `HTTP/2 200`.
- `certificate/argocd-server-public-tls` is `Ready=True`.
- `curl -I https://argocd.yolo.scapegoat.dev` returns `HTTP/2 200`.
- `terraform plan -no-color` returns `No changes`.
- Argo CD reports `demo-stack` as `Healthy` but still `OutOfSync`, with `demo-stack-postgres` shown as the remaining unsynced resource.
- The initial cloud-init run failed, but the bootstrap script was rerun successfully after the repo fix for `app/go.sum`.

## Exit Criteria

- Terraform finishes without errors.
- The server becomes reachable over SSH.
- `kubectl get nodes` shows the single node as `Ready`.
- `kubectl -n argocd get applications` shows `demo-stack` present and healthy.
- `https://<app_subdomain>.<base_domain>` serves the demo app with a valid certificate.
- `https://argocd.yolo.scapegoat.dev` serves the Argo CD UI with a valid certificate.

## Notes

- The bootstrap path assumes the Git repo is public unless extra Argo CD repo credentials are configured later.
- DNS must point to the server before Let's Encrypt HTTP-01 validation can succeed.
- This stack is intentionally single-node and uses local-path storage for PostgreSQL.

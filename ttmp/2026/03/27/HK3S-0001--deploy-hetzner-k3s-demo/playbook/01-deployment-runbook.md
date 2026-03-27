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

Step 1: gather the external values that are not present in the repository, confirm which defaults to keep, then create the local `terraform.tfvars`.

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

## Exit Criteria

- Terraform finishes without errors.
- The server becomes reachable over SSH.
- `kubectl get nodes` shows the single node as `Ready`.
- `kubectl -n argocd get applications` shows `demo-stack` present and healthy.
- `https://demo.<base_domain>` serves the demo app with a valid certificate.

## Notes

- The bootstrap path assumes the Git repo is public unless extra Argo CD repo credentials are configured later.
- DNS must point to the server before Let's Encrypt HTTP-01 validation can succeed.
- This stack is intentionally single-node and uses local-path storage for PostgreSQL.

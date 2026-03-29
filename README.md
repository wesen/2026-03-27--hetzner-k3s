# Hetzner single-node K3s + Argo CD platform

This repo is the source of truth for a single-node Hetzner K3s cluster. Terraform creates the VM and firewall, cloud-init bootstraps K3s and Argo CD, and Argo CD then reconciles the platform and application packages defined here.

The cluster currently runs:
- platform services: Vault, Keycloak, PostgreSQL, MySQL, Redis, cert-manager, public Argo CD
- application services: CoinVault, CoinVault SQL debugger, Pretext explorer
- public ingress and TLS through the built-in K3s Traefik controller

If you are here because you want to deploy a new app, start with:
- [docs/source-app-deployment-infrastructure-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/source-app-deployment-infrastructure-playbook.md)

That is the canonical “bring your repo to this platform” guide.

## What this stack does

- Terraform creates:
  - one Hetzner Cloud server
  - one Hetzner Cloud firewall
  - one Hetzner Cloud SSH key resource
- cloud-init on first boot:
  - installs K3s
  - installs cert-manager
  - installs Argo CD
  - clones this repo on the server
  - seeds the initial bootstrap application path
- Argo CD then deploys:
  - platform services such as Vault, Keycloak, PostgreSQL, MySQL, Redis, and the public Argo CD UI
  - application services such as CoinVault and Pretext
  - ingress and TLS resources for public endpoints

## Start Here

Choose the entry point that matches what you are trying to do:

- I want to bring a new source repo onto this platform:
  - [docs/source-app-deployment-infrastructure-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/source-app-deployment-infrastructure-playbook.md)
- I have a public repo and want the simplest GHCR path:
  - [docs/public-repo-ghcr-argocd-deployment-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/public-repo-ghcr-argocd-deployment-playbook.md)
- I need the standardized repo and GitOps layout rules:
  - [docs/app-packaging-and-gitops-pr-standard.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/app-packaging-and-gitops-pr-standard.md)
- I need the private GHCR pull-secret pattern:
  - [HK3S-0014 index](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/29/HK3S-0014--add-vault-backed-ghcr-image-pull-secret-pattern-for-private-app-images/index.md)
- I need to operate backups and scratch restores for the shared data services:
  - [docs/cluster-data-services-backup-and-restore-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/cluster-data-services-backup-and-restore-playbook.md)
- I need stable SSH and `kubectl` access through Tailscale:
  - [docs/tailscale-k3s-admin-access-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/tailscale-k3s-admin-access-playbook.md)
- I need to operate Vault snapshots and understand the whole-node backup layer:
  - [docs/vault-snapshot-and-server-backup-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/vault-snapshot-and-server-backup-playbook.md)
- I need the base platform bring-up guide:
  - [docs/hetzner-k3s-server-setup.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/hetzner-k3s-server-setup.md)

## Architecture

The operating model is:

```text
Terraform
  -> Hetzner VM + firewall
cloud-init
  -> K3s + Argo CD bootstrap
GitOps repo
  -> Argo CD Applications + Kustomize packages
Argo CD
  -> cluster reconciliation
Vault + VSO
  -> workload secrets and private registry credentials
```

## Requirements

- A Hetzner Cloud project + API token
- A domain you control
- DNS for the hostnames you want to expose pointing to the server's public IP after Terraform creates it
- An SSH public key
- A **Git repository URL for this repo**
  - easiest path: push this repo to a **public** GitHub repo first
  - if you want a private repo, add Argo CD repo credentials after bootstrap

## Repo Layout

- `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
  - Hetzner infrastructure
- `cloud-init.yaml.tftpl`
  - first-boot bootstrap logic
- `gitops/applications/`
  - Argo CD `Application` objects
- `gitops/kustomize/`
  - repo-owned workload packages
- `docs/`
  - long-form operator and intern-facing playbooks
- `ttmp/`
  - ticket workspaces, investigations, diaries, and implementation history
- `scripts/`
  - local operator helpers that are intentionally outside GitOps state

## Quick start

1. Push this directory to a Git repository.
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in the values.
3. Run:

   ```bash
   terraform init
   terraform apply
   ```

4. Create the DNS records once Terraform prints the server IP:

   ```
   <app>.<your-domain>          ->  <server IPv4>
   *.yolo.<your-domain>         ->  <server IPv4>
   ```

5. Watch first-boot provisioning:

   ```bash
   ssh root@<server-ip> 'tail -f /var/log/cloud-init-output.log'
   ```

6. Fetch a kubeconfig that points at the current admin endpoint:

   ```bash
   ./scripts/get-kubeconfig-tailscale.sh
   export KUBECONFIG=$PWD/kubeconfig-<tailscale-host>.yaml
   kubectl get nodes
   ```

   For the live cluster, Tailscale is now the preferred operator path and public `6443` is disabled.

7. Check Argo CD:

   ```bash
   kubectl -n argocd get applications
   kubectl -n argocd port-forward svc/argocd-server 8080:443
   ```

   Then open `https://localhost:8080`. If `argocd-public` is synced, `https://argocd.yolo.scapegoat.dev` should also work directly.

8. Get the initial Argo CD admin password:

   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret \
     -o jsonpath='{.data.password}' | base64 -d && echo
   ```

9. Apply a repo-managed Argo CD application if it is not already present:

   ```bash
   kubectl apply -f gitops/applications/argocd-public.yaml
   kubectl -n argocd annotate application argocd-public argocd.argoproj.io/refresh=hard --overwrite
   ```

10. Open one of the live public endpoints:

   ```
   https://argocd.yolo.scapegoat.dev
   https://coinvault.yolo.scapegoat.dev
   ```

## Day-2 Operations

Common checks:

```bash
./scripts/get-kubeconfig-tailscale.sh
export KUBECONFIG=$PWD/kubeconfig-<tailscale-host>.yaml

kubectl get nodes
kubectl -n argocd get applications
kubectl -n argocd get application coinvault -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'
kubectl -n vault get pods
kubectl -n postgres get pods
kubectl -n mysql get pods
kubectl -n redis get pods
```

Public endpoints:

- `https://argocd.yolo.scapegoat.dev`
- `https://vault.yolo.scapegoat.dev`
- `https://auth.yolo.scapegoat.dev`
- `https://coinvault.yolo.scapegoat.dev`
- `https://coinvault-sql.yolo.scapegoat.dev`
- `https://pretext.yolo.scapegoat.dev`

## Important caveats

- This is **single-node** and **non-HA**.
- PostgreSQL uses **local-path** storage on the node. If the node dies, the volume dies with it unless you have separate backups.
- The default setup assumes a **public Git repo** so Argo CD can read it without credentials.
- Use Let's Encrypt **staging** first if you are iterating heavily on DNS/TLS.

## Key Documents

- [docs/source-app-deployment-infrastructure-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/source-app-deployment-infrastructure-playbook.md)
  - canonical source-repo onboarding guide
- [docs/coinvault-k3s-deployment-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/coinvault-k3s-deployment-playbook.md)
  - end-to-end operator guide for CoinVault
- [docs/argocd-app-setup.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/argocd-app-setup.md)
  - how Argo CD apps are structured here
- [docs/hetzner-k3s-server-setup.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/hetzner-k3s-server-setup.md)
  - platform bring-up and cluster bootstrap
- [docs/cluster-data-services-backup-and-restore-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/cluster-data-services-backup-and-restore-playbook.md)
  - operator playbook for shared PostgreSQL, MySQL, and Redis backups and scratch restores
- [docs/tailscale-k3s-admin-access-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/tailscale-k3s-admin-access-playbook.md)
  - operator playbook for moving SSH and `kubectl` onto the Tailscale tailnet path
- [docs/vault-snapshot-and-server-backup-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/vault-snapshot-and-server-backup-playbook.md)
  - operator playbook for Vault Raft snapshots and Hetzner whole-node backups
- [docs/vault-backed-postgres-bootstrap-job-pattern.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/vault-backed-postgres-bootstrap-job-pattern.md)
  - declarative app database provisioning pattern

## Vault workload auth notes

The K3s Vault deployment supports a second bootstrap layer for machine auth:

- Git manages the smoke namespace/service account in `gitops/kustomize/vault-kubernetes-auth`
- the operator configures the Vault-side auth backend, policies, and roles with `scripts/bootstrap-vault-kubernetes-auth.sh`
- `scripts/validate-vault-kubernetes-auth.sh` proves that a real Kubernetes service account JWT can log into Vault and read only its own subtree

## Vault bootstrap notes

Vault is intentionally bootstrapped in two layers:

- Git manages the Argo CD `Application` in `gitops/applications/vault.yaml`
- the operator creates the AWS KMS credential `Secret` locally with `scripts/bootstrap-vault-aws-kms-secret.sh`

That split keeps AWS credentials out of git while still making the actual Vault deployment declarative and reviewable.

Example:

```bash
./scripts/get-kubeconfig-tailscale.sh
export KUBECONFIG=$PWD/kubeconfig-<tailscale-host>.yaml
export AWS_PROFILE=manuel
./scripts/bootstrap-vault-aws-kms-secret.sh
kubectl apply -f gitops/applications/vault.yaml
```

## Suggested first changes

- move PostgreSQL to a managed service or at least a separate volume / backup plan
- add repo credentials if you want the GitOps repo private
- finish upgrade and rollback playbooks for the shared data services
- keep moving remaining apps onto the standardized CI -> GHCR -> GitOps PR path

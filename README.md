# Hetzner single-node K3s + Argo CD platform

This repo provisions **one Hetzner Cloud VM** with **Terraform**, bootstraps **K3s** and **Argo CD** with **cloud-init**, installs **cert-manager**, and then uses **GitOps** to run platform and application workloads on top of that cluster.

The cluster exposes workloads over **HTTPS** through the **K3s-packaged Traefik ingress controller**. Shared PostgreSQL, MySQL, Redis, Vault, Keycloak, CoinVault, Pretext, and the public Argo CD UI are all managed from this repository.

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

## Requirements

- A Hetzner Cloud project + API token
- A domain you control
- DNS for the hostnames you want to expose pointing to the server's public IP after Terraform creates it
- An SSH public key
- A **Git repository URL for this repo**
  - easiest path: push this repo to a **public** GitHub repo first
  - if you want a private repo, add Argo CD repo credentials after bootstrap

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

6. Fetch a kubeconfig that points at the server:

   ```bash
   ./scripts/get-kubeconfig.sh <server-ip>
   export KUBECONFIG=$PWD/kubeconfig-<server-ip>.yaml
   kubectl get nodes
   ```

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

## Important caveats

- This is **single-node** and **non-HA**.
- PostgreSQL uses **local-path** storage on the node. If the node dies, the volume dies with it unless you have separate backups.
- The demo app image is built **locally on the node** and imported into K3s. That is fine for a one-node demo stack, but you would normally move to a real registry for anything larger.
- The default setup assumes a **public Git repo** so Argo CD can read it without credentials.
- Use Let's Encrypt **staging** first if you are iterating heavily on DNS/TLS.

## Files

- `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`: Hetzner infra
- `cloud-init.yaml.tftpl`: first-boot bootstrap logic
- `docs/`: long-form intern-facing operational guides in Glazed help-page format
- `docs/coinvault-k3s-deployment-playbook.md`: end-to-end operator guide for the CoinVault K3s deployment path
- `docs/public-repo-ghcr-argocd-deployment-playbook.md`: how to publish public-repo images to GHCR and deploy them through Argo CD
- `docs/app-packaging-and-gitops-pr-standard.md`: standard package shape for app repos and the CI-created GitOps pull-request model
- `docs/source-app-deployment-infrastructure-playbook.md`: detailed end-to-end guide for building deployment infrastructure around a source repository, from CI to GitOps PR to live rollout
- `docs/vault-backed-postgres-bootstrap-job-pattern.md`: how to provision app-specific PostgreSQL databases and roles declaratively with Vault, VSO, and a bootstrap Job
- `gitops/applications/argocd-public.yaml`: Argo CD `Application` that restores and exposes the Argo CD server itself
- `gitops/kustomize/argocd-public`: dedicated package that owns `argocd-server`, `argocd-cmd-params-cm`, and the public ingress
- `gitops/applications/coinvault.yaml`: Argo CD `Application` for the first migrated real app
- `gitops/applications/vault.yaml`: Argo CD `Application` for the K3s-hosted Vault deployment
- `gitops/applications/vault-kubernetes-auth.yaml`: Argo CD `Application` for the Kubernetes-auth smoke namespace/service account
- `gitops/kustomize/vault-kubernetes-auth`: smoke-test Kubernetes objects for the Vault Kubernetes auth path
- `gitops/charts/demo-stack`: legacy Helm bootstrap compatibility path
- `scripts/get-kubeconfig.sh`: helper to fetch a usable kubeconfig
- `scripts/bootstrap-vault-aws-kms-secret.sh`: local helper to create the non-git Kubernetes secret for Vault AWS KMS auto-unseal
- `scripts/bootstrap-vault-kubernetes-auth.sh`: local helper to enable/configure Vault Kubernetes auth and seed baseline policies/roles
- `scripts/validate-vault-kubernetes-auth.sh`: local helper to prove service-account login and least-privilege behavior

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
export KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml
export AWS_PROFILE=manuel
./scripts/bootstrap-vault-aws-kms-secret.sh
kubectl apply -f gitops/applications/vault.yaml
```

## Suggested first changes

- move PostgreSQL to a managed service or at least a separate volume / backup plan
- move the demo app image build to CI and push to a registry
- add repo credentials if you want the GitOps repo private
- replace the demo secret values with a real secret-management path

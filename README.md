# Hetzner single-node K3s + Argo CD demo

This repo provisions **one Hetzner Cloud VM** with **Terraform**, bootstraps **K3s** and **Argo CD** with **cloud-init**, installs **cert-manager**, and deploys a **demo Go web app** plus **PostgreSQL** inside K3s.

The demo app is exposed to the public internet over **HTTPS** through the **K3s-packaged Traefik ingress controller**. PostgreSQL uses K3s **local-path** storage, so its data lives on the node's local disk.

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
  - builds the demo Go image locally on the node
  - imports that image into K3s containerd
  - creates the PostgreSQL secret in Kubernetes
  - bootstraps an Argo CD `Application`
- Argo CD then deploys:
  - a `ClusterIssuer` for Let's Encrypt HTTP-01
  - PostgreSQL as a single-replica `StatefulSet`
  - the demo Go app as a `Deployment`
  - a `Service` and `Ingress`

## Requirements

- A Hetzner Cloud project + API token
- A domain you control
- DNS for `demo.<your-domain>` pointing to the server's public IP after Terraform creates it
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

4. Create the DNS record for the app host once Terraform prints the server IP:

   ```
   demo.<your-domain>  ->  <server IPv4>
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

   Then open `https://localhost:8080`.

8. Get the initial Argo CD admin password:

   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret \
     -o jsonpath='{.data.password}' | base64 -d && echo
   ```

9. Open the demo app:

   ```
   https://demo.<your-domain>
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
- `gitops/kustomize/demo-stack`: Kustomize package deployed by Argo CD
- `gitops/applications/demo-stack.yaml`: current Argo CD `Application` manifest
- `gitops/charts/demo-stack`: legacy Helm bootstrap compatibility path
- `app/`: demo Go app source + Dockerfile
- `scripts/get-kubeconfig.sh`: helper to fetch a usable kubeconfig

## Suggested first changes

- move PostgreSQL to a managed service or at least a separate volume / backup plan
- move the demo app image build to CI and push to a registry
- add repo credentials if you want the GitOps repo private
- replace the demo secret values with a real secret-management path

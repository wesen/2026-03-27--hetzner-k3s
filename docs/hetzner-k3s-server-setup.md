---
Title: "Set Up a Hetzner K3s Server for This Repository"
Slug: "hetzner-k3s-server-setup"
Short: "Provision the Hetzner server, bootstrap K3s and Argo CD, configure DNS and TLS, and validate the deployment end to end."
Topics:
- hetzner
- terraform
- kubernetes
- k3s
- argocd
- dns
- cert-manager
- gitops
Commands:
- terraform
- ssh
- kubectl
- git
Flags: []
IsTopLevel: true
IsTemplate: false
ShowPerDefault: true
SectionType: Tutorial
---

## What This Page Covers

This page explains how to bring up the full single-node Hetzner environment used by this repository. It covers what the moving parts are, how they fit together, which inputs you need, the exact operator flow from provisioning through validation, and the cleanup decisions that keep the environment maintainable afterward.

This workflow matters because the deployment is not only “create a VM and run Kubernetes.” It combines Terraform, cloud-init, K3s, cert-manager, Argo CD, DNS, TLS, and GitOps packaging. A new intern needs to understand where each responsibility lives so they can tell the difference between an infrastructure problem, a bootstrap problem, a cluster problem, and a GitOps problem.

## What You Will Build

You will build one Hetzner Cloud VM that runs K3s and hosts a demo application plus PostgreSQL. The node exposes the app publicly over HTTPS and also exposes Argo CD over its own HTTPS hostname. The final state should give you a working app, a working Argo CD UI, and a GitOps-managed deployment source that stays reconciled with Terraform.

At the end of the flow, you should be able to do all of the following:

- `ssh` into the server
- use `kubectl` against the cluster
- open the app over HTTPS
- open Argo CD over HTTPS
- run `terraform plan` and see `No changes`
- run `kubectl -n argocd get applications` and see the platform apps, including `argocd-public`, as healthy

## Core Concepts

This section explains the concepts behind the workflow. You should read it before running commands because each later step assumes you know which layer you are currently operating in and why it exists.

### Hetzner and Terraform

Hetzner provides the VM, firewall, IP addresses, and SSH key registration. Terraform is only responsible for provisioning those infrastructure objects and injecting first-boot configuration through `user_data`.

This distinction matters because Terraform does not manage day-two Kubernetes state very well in this repo. If you change bootstrap `user_data` after the server already exists, Hetzner treats that as immutable and Terraform wants to replace the server. That is why later cluster-facing work gets moved into GitOps instead of staying in bootstrap.

### Cloud-init and First Boot

`cloud-init.yaml.tftpl` runs once, at first boot, and is responsible for the initial cluster bring-up. It installs K3s, cert-manager, and Argo CD, clones the repository, builds the app image locally on the node, creates the PostgreSQL secret, and seeds the first Argo CD `Application`.

This matters because cloud-init is a bootstrap tool, not a steady-state config manager. If first boot fails, you investigate bootstrap logs. If the cluster is already up and only the app is wrong, you usually should not be editing cloud-init anymore.

### K3s

K3s is the lightweight Kubernetes distribution running on the server. In this repository it provides the control plane, container runtime integration, the packaged Traefik ingress controller, and local-path storage for PostgreSQL.

This matters because the cluster is intentionally single-node and non-HA. That is acceptable for a demo or internal environment, but it changes the operational expectations: local storage is tied to the node, and node replacement is a real event, not an invisible scaling exercise.

### Argo CD and GitOps

Argo CD watches paths in the Git repository and applies Kubernetes resources from those paths into the cluster. The current repo uses multiple repo-managed `Application` objects, including `coinvault`, `keycloak`, `vault`, `pretext`, and `argocd-public`.

This matters because the cluster’s long-term source of truth is Git, not shell history. If something is only present because you ran `kubectl apply` manually and never moved it into GitOps, you have configuration drift even if the cluster looks healthy.

### Why Both Helm and Kustomize Exist in the Repo

The live deployment now uses Kustomize, but the old Helm chart still exists as a bootstrap compatibility path. The reason is practical: changing first-boot `user_data` on the already-running server would have reintroduced Terraform replacement pressure.

This matters because an intern should not “clean up” the old chart casually. Right now the correct mental model is:

- `gitops/applications/*` and `gitops/kustomize/*` are the live deployment sources
- `gitops/charts/demo-stack` is legacy bootstrap compatibility
- if you want to remove the chart completely, you must redesign bootstrap carefully rather than deleting files in place

## Repository Layout

This section explains where the important files live. You need this map because the workflow crosses infrastructure, bootstrap, app source, and GitOps packaging.

- [`main.tf`](../main.tf) and [`variables.tf`](../variables.tf): Hetzner infrastructure and required inputs
- [`cloud-init.yaml.tftpl`](../cloud-init.yaml.tftpl): first-boot bootstrap logic
- [`scripts/get-kubeconfig.sh`](../scripts/get-kubeconfig.sh): helper to fetch a usable kubeconfig
- [`gitops/applications/argocd-public.yaml`](../gitops/applications/argocd-public.yaml): repo-managed Argo CD `Application` for the public Argo CD UI
- [`gitops/kustomize/argocd-public/kustomization.yaml`](../gitops/kustomize/argocd-public/kustomization.yaml): dedicated Argo CD public-exposure package
- [`gitops/applications/coinvault.yaml`](../gitops/applications/coinvault.yaml): repo-managed Argo CD `Application` for a real app
- [`gitops/charts/demo-stack/README.md`](../gitops/charts/demo-stack/README.md): explains why the legacy chart still exists

## Prerequisites

This section explains what you need before you can start. It is not enough to have access to the repo. You need credentials, a Git URL the node can clone, and DNS control over the target domain.

- A Hetzner Cloud API token
- A public SSH key
- Control over the target DNS zone
- This repository pushed to a Git URL reachable by the server
- `terraform`, `ssh`, `kubectl`, and `git` installed locally
- A machine IP or CIDR you are comfortable allowing through the Hetzner firewall for SSH

For the current environment, the concrete values were:

- `repo_url = "https://github.com/wesen/2026-03-27--hetzner-k3s.git"`
- `base_domain = "scapegoat.dev"`
- `app_subdomain = "k3s"`
- public Argo CD hostname `argocd.yolo.scapegoat.dev`

## Step 1: Prepare the Repository and Secrets

This step prepares the source of truth before any infrastructure is created. You make sure the Git repository is reachable by the future node and that the Terraform input values are available locally without committing secrets.

Why this matters: if the node cannot clone the repo or the repo is missing necessary content, first boot fails later on the server and becomes much harder to debug.

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
cp terraform.tfvars.example terraform.tfvars
```

Fill in at least these values in `terraform.tfvars`:

- `hcloud_token`
- `ssh_public_key`
- `admin_cidrs`
- `repo_url`
- `base_domain`
- `acme_email`
- `postgres_password`

Do not commit `terraform.tfvars`. The repo already ignores `*.tfvars`.

## Step 2: Provision the Hetzner Infrastructure

This step creates the Hetzner server, firewall, and uploaded SSH key. Terraform also injects the cloud-init template into the server’s `user_data`.

Why this matters: this is the moment where infrastructure state and bootstrap state get tied together. After the server exists, changing `user_data` is expensive, so you want the Terraform inputs to be correct before you apply.

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
terraform init
terraform validate
terraform apply
```

Expected outputs include:

- server IPv4
- server IPv6
- SSH command
- app URL

If Hetzner says the chosen server type is not orderable in the selected location, pick a currently orderable type and re-run. In this environment, `cpx31` in `fsn1` was not available and `cpx32` was used instead.

## Step 3: Watch First-Boot Bootstrap

This step follows cloud-init while the node installs K3s and Argo CD and seeds the first application. You are verifying that the cluster actually becomes usable, not just that Terraform finished.

Why this matters: Terraform success only proves the VM exists. It does not prove that K3s, cert-manager, Argo CD, image build/import, or the bootstrapped application all succeeded.

```bash
ssh root@<server-ip> 'tail -f /var/log/cloud-init-output.log'
```

If bootstrap fails, inspect the logs carefully. A common failure mode is assuming the error is “on the server” when the root cause is actually in the Git repository contents that the server cloned.

## Step 4: Create DNS Records

This step points the public hostnames at the server IP after Terraform has told you what that IP is. The app hostname must resolve before Let’s Encrypt HTTP-01 validation can succeed.

Why this matters: cert-manager and ingress can be healthy internally while public HTTPS is still blocked on DNS. In this deployment the needed records were:

- `k3s.scapegoat.dev -> 91.98.46.169`
- `*.yolo.scapegoat.dev -> 91.98.46.169`

The wildcard record is what made `argocd.yolo.scapegoat.dev` possible later without another DNS design change.

## Step 5: Fetch Kubeconfig and Validate the Cluster

This step moves you from VM-level access to cluster-level access. Once kubeconfig works, most further operational checks happen through Kubernetes rather than SSH.

Why this matters: you need a clean operator path to inspect nodes, pods, ingress, certificates, and Argo CD application state without continually logging into the server.

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
./scripts/get-kubeconfig.sh <server-ip>
export KUBECONFIG=$PWD/kubeconfig-<server-ip>.yaml
kubectl get nodes
kubectl -n argocd get applications
```

The node should be `Ready`. The applications may still be progressing at this stage, but you should at least see Argo CD running and the repo-managed `Application` objects present.

## Step 6: Validate the Public Endpoints

This step proves the user-facing and operator-facing paths both work. For this repo that means the app itself and the Argo CD UI.

Why this matters: internal cluster health is not enough if ingress, certificates, or DNS are still wrong from an operator’s perspective.

```bash
curl -I https://k3s.scapegoat.dev
curl -I https://argocd.yolo.scapegoat.dev
kubectl -n argocd get applications
```

The clean target state is:

- both HTTPS endpoints return `HTTP/2 200`
- `kubectl -n argocd get applications` shows `argocd-public   Synced   Healthy`

If Firefox or another browser reports a self-signed certificate for `argocd.yolo.scapegoat.dev`, that usually means Traefik is serving its fallback certificate because the dedicated `argocd-public` route is missing or `argocd-server` itself is not running. The fast checks are:

```bash
kubectl -n argocd get application argocd-public
kubectl -n argocd get deploy argocd-server
kubectl -n argocd get ingress argocd-server-public
openssl s_client -connect argocd.yolo.scapegoat.dev:443 \
  -servername argocd.yolo.scapegoat.dev </dev/null 2>/dev/null | \
  openssl x509 -noout -subject -issuer
```

The healthy external certificate chain should show a Let's Encrypt issuer, not `TRAEFIK DEFAULT CERT`.

Important TLS note for future app ingresses:

- the live cert-manager `ClusterIssuer` name on this cluster is `letsencrypt-prod`
- do not annotate new ingresses with `cert-manager.io/cluster-issuer: letsencrypt-production`
- if you use the wrong name, Traefik serves its default self-signed certificate immediately and cert-manager never progresses past `CertificateRequest` because the referenced issuer does not exist

Quick check:

```bash
kubectl get clusterissuer
```

At the time of writing, the expected output includes:

```text
letsencrypt-prod   True
```

## Step 7: Switch the Live App to the Repo-Managed Kustomize Source

This step is specific to the current state of the repository. First boot still seeds a legacy Helm-compatible application path for bootstrap stability, but the live deployment should be moved onto the repo-managed Kustomize source.

Why this matters: this is what gets you to the long-term cleaned-up state without changing Terraform-managed `user_data` on an already-running server.

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
kubectl apply -f gitops/applications/argocd-public.yaml
kubectl -n argocd annotate application argocd-public argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd get application argocd-public -o jsonpath='{.spec.source.path}{"\n"}'
```

The expected source path after this step is:

```text
gitops/kustomize/argocd-public
```

## Step 8: Confirm Terraform Is Still Reconciled

This step is the final protection against accidentally reintroducing server replacement pressure. It confirms that the live cleanup you performed stayed on the cluster/GitOps side rather than drifting back into Terraform-managed bootstrap state.

Why this matters: a deployment is not truly clean if the cluster looks healthy but `terraform plan` wants to recreate the only node.

```bash
cd /home/manuel/code/wesen/2026-03-27--hetzner-k3s
terraform plan -no-color
```

The expected result is:

```text
No changes. Your infrastructure matches the configuration.
```

## Final Validation Checklist

This section summarizes the end state. Use it as the quick acceptance checklist when you hand the environment to another operator or intern.

- `terraform plan -no-color` reports `No changes`
- `kubectl get nodes` shows the node as `Ready`
- `kubectl -n argocd get applications` shows `argocd-public   Synced   Healthy`
- `kubectl -n argocd get application argocd-public -o jsonpath='{.spec.source.path}'` prints `gitops/kustomize/argocd-public`
- `curl -I https://k3s.scapegoat.dev` returns `HTTP/2 200`
- `curl -I https://argocd.yolo.scapegoat.dev` returns `HTTP/2 200`
- CoreDNS uses `forward . /etc/resolv.conf`

## Troubleshooting

This table covers the problems most likely to confuse a new operator. The focus is not only on the fix, but on identifying which layer actually owns the problem.

| Problem | Cause | Solution |
|---|---|---|
| `terraform apply` fails because the SSH key already exists in Hetzner | The uploaded public key name already exists in the Hetzner project | Import the existing key into state or choose a different Terraform resource name before retrying |
| `terraform apply` fails because the server type is unavailable | Hetzner does not currently offer that type in the selected location | Pick an orderable type, re-run apply, and record the decision |
| The server exists but SSH is not ready yet | The VM is still booting or cloud-init has not reached the SSH-ready stage | Wait and retry; do not assume Terraform success means K3s is ready |
| Cloud-init fails during app bootstrap | The repo contents cloned on the server are wrong or incomplete | Read `/var/log/cloud-init-output.log`, fix the repo, push the fix, and rerun the bootstrap script if needed |
| The app is reachable over HTTP by IP plus `Host` header, but HTTPS is failing | DNS or ACME validation is not yet complete | Verify public DNS, cert-manager resources, and ingress status before changing the app |
| Argo CD is `Healthy` but `OutOfSync` | The manifests in Git do not exactly match the stored Kubernetes spec | Inspect the specific drift and either declare the defaulted fields explicitly or correct the live/object source mismatch |
| `terraform plan` wants to replace the server after a cleanup change | You changed Terraform-managed bootstrap state such as `user_data` | Move the change into GitOps/Kubernetes instead, or redesign bootstrap deliberately rather than patching it ad hoc |

## See Also

- [Set Up an Argo CD Application in This Repository](./argocd-app-setup.md) — focused guide for creating or migrating the GitOps application itself
- [`README.md`](../README.md) — concise operator overview of the repository
- [`gitops/applications/argocd-public.yaml`](../gitops/applications/argocd-public.yaml) — the dedicated Argo CD public-exposure `Application`
- [`gitops/kustomize/argocd-public/kustomization.yaml`](../gitops/kustomize/argocd-public/kustomization.yaml) — the package that owns `argocd-server`, `argocd-cmd-params-cm`, and the public ingress

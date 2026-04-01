---
Title: "Operator Troubleshooting FAQ"
Slug: "operator-troubleshooting-faq"
Short: "Common operator failures in this cluster, what they mean, and how to fix them."
Topics:
- troubleshooting
- operations
- argocd
- kubernetes
- tailscale
- ingress
- vault
Commands:
- kubectl
- ssh
- curl
Flags: []
IsTopLevel: true
IsTemplate: false
ShowPerDefault: true
SectionType: GeneralTopic
---

## What This Page Is

This page is a practical FAQ for the failures an operator is most likely to hit while working with this repository and the live cluster. It is intentionally written for people who may not already know how Argo CD, Kubernetes `Job` immutability, Tailscale kubeconfig handling, or Traefik certificate fallbacks work.

Each entry answers three questions:

- what the error usually means
- why it happens in this specific environment
- what the safe fix is

## How To Use This Page

When something breaks, resist the urge to immediately apply random `kubectl` commands. Start by identifying which layer is actually failing:

- access path
- Argo CD sync
- pod startup
- secret delivery
- public ingress and TLS

Then find the closest matching FAQ entry below.

## FAQ

### `kubectl` is trying to talk to `kubernetes.docker.internal:6443`

Typical symptom:

```text
The connection to the server kubernetes.docker.internal:6443 was refused
```

What it means:

- `kubectl` is not using the Tailscale kubeconfig you think it is using
- it has fallen back to your default local kubeconfig

Why it happens here:

- this repo now expects Tailscale-based admin access
- if `KUBECONFIG` is empty, your shell may silently use a different local cluster config

Safe fix:

```bash
export K3S_TAILSCALE_DNS=k3s-demo-1.tail879302.ts.net
export K3S_TAILSCALE_IP=100.73.36.123
export K3S_TAILNET_KUBECONFIG=$PWD/.cache/kubeconfig-tailnet.yaml
export KUBECONFIG=$K3S_TAILNET_KUBECONFIG
mkdir -p "$PWD/.cache"

./scripts/get-kubeconfig-tailscale.sh
kubectl get nodes
```

If this fixes the issue, the problem was not the cluster. It was your local kubeconfig selection.

### `kubectl` times out to the public server IP on port `6443`

Typical symptom:

```text
dial tcp <public-ip>:6443: i/o timeout
```

What it means:

- you are trying to use the old public Kubernetes API path

Why it happens here:

- public Kubernetes API exposure on `6443` has been tightened
- the normal admin path is now through Tailscale

Safe fix:

- stop using the public IP kubeconfig
- fetch a Tailscale kubeconfig instead

See:

- [tailscale-k3s-admin-access-playbook.md](./tailscale-k3s-admin-access-playbook.md)

### Firefox shows `MOZILLA_PKIX_ERROR_SELF_SIGNED_CERT` for a public hostname

Typical symptom:

- browser says the site is using a self-signed certificate
- certificate details show something like `TRAEFIK DEFAULT CERT`

What it means:

- Traefik received the request, but there is no matching live ingress route for that hostname

Why it happens here:

- if no ingress claims the hostname, Traefik falls back to its default self-signed certificate

### Argo says `Synced`, but the app still serves old config

Typical symptom:

- you merge a GitOps PR that changes a ConfigMap
- the Argo Application is `Synced`
- the app endpoint still returns the old configuration value

What it means:

- the desired state changed
- but the running pod did not actually start with the new config yet

Why it happens here:

- this repo has historically used handwritten ConfigMaps plus `subPath` file mounts
- a `subPath`-mounted file does not behave like a simple “hot updated” config source in the way many operators expect

Safe fix:

Short term:

```bash
kubectl -n <namespace> rollout restart deploy/<app>
kubectl -n <namespace> rollout status deploy/<app>
```

Longer term:

- refactor the Kustomize package to use generated config and rollout-on-change

See:

- [kustomize-generated-config-rollout-pattern.md](./kustomize-generated-config-rollout-pattern.md)
- this is usually a routing or resource-ownership problem, not a cert-manager problem

Safe fix:

- check whether the ingress exists
- check whether the hostname is correct
- check whether the Argo application that should own the ingress is healthy

Good first commands:

```bash
kubectl get ingress -A
kubectl -n argocd get applications
```

### Argo CD sync fails with `Job.batch ... field is immutable`

Typical symptom:

```text
Job.batch "draft-review-db-bootstrap" is invalid:
spec.selector: Required value
...
field is immutable
```

or:

```text
Job.batch "keycloak-db-bootstrap" is invalid:
spec.selector: Required value
...
field is immutable
```

What it means:

- Argo is trying to update an existing Kubernetes `Job` in place
- Kubernetes does not allow important parts of a `Job`'s identity and pod template to be changed after creation

Why it happens here:

- bootstrap database jobs were originally modeled as normal named `Job` resources with `Replace=true`
- that encourages Argo to try to replace them as if they were mutable long-lived resources
- they are not

Safe fix:

1. change the manifest to an Argo hook job:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: Sync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded
```

2. remove the bad existing job:

```bash
kubectl -n draft-review delete job draft-review-db-bootstrap
kubectl -n keycloak delete job keycloak-db-bootstrap
```

3. force Argo to refresh:

```bash
kubectl -n argocd annotate application draft-review argocd.argoproj.io/refresh=hard --overwrite
kubectl -n argocd annotate application keycloak argocd.argoproj.io/refresh=hard --overwrite
```

Why this is the right fix:

- bootstrap jobs are one-shot actions
- hooks tell Argo to recreate them cleanly rather than mutate them in place

### A public app works, but `ssh` and `kubectl` suddenly time out

Typical symptom:

- `https://...` endpoints are still fine
- `ssh` on `22` and `kubectl` on `6443` fail

What it means:

- the Hetzner firewall is probably restricting admin access to an older public IP

Why it happens here:

- `admin_cidrs` controls the fallback admin path
- if your ISP address changes, the firewall can block you while public web traffic still works

Safe fix:

- prefer Tailscale for the normal operator path
- if you must restore public fallback access, update local `terraform.tfvars` and re-run `terraform apply`

### A pod is `ImagePullBackOff` after a new GHCR rollout

What it usually means:

- the image tag does not exist
- or the package is private and the namespace lacks working `imagePullSecrets`

Why it happens here:

- some repos publish public GHCR images
- others publish private GHCR images and need the Vault/VSO-backed pull-secret path

Safe fix:

- confirm the exact image tag exists in GHCR
- confirm the workload namespace has the correct pull secret
- confirm the pod or service account references it

Related reading:

- [source-app-deployment-infrastructure-playbook.md](./source-app-deployment-infrastructure-playbook.md)
- [app-packaging-and-gitops-pr-standard.md](./app-packaging-and-gitops-pr-standard.md)

### Vault-backed secret sync is missing in Kubernetes

What it usually means:

- Vault Secrets Operator is not healthy
- the `VaultAuth` or `VaultStaticSecret` object is wrong
- the underlying Vault policy or role does not allow the read

Safe first checks:

```bash
kubectl -n vault-secrets-operator-system get pods
kubectl get vaultauth -A
kubectl get vaultstaticsecret -A
kubectl describe vaultstaticsecret -A
```

If the operator is healthy but the secret is not appearing, inspect the Vault auth role and the bound service account relationship.

## When To Stop Guessing and Read the Longer Playbook

Use the longer documents when the FAQ gets you to the right subsystem but you still need deeper procedure:

- [operator-quickstart.md](./operator-quickstart.md)
- [tailscale-k3s-admin-access-playbook.md](./tailscale-k3s-admin-access-playbook.md)
- [argocd-app-setup.md](./argocd-app-setup.md)
- [cluster-data-services-backup-and-restore-playbook.md](./cluster-data-services-backup-and-restore-playbook.md)
- [vault-snapshot-and-server-backup-playbook.md](./vault-snapshot-and-server-backup-playbook.md)

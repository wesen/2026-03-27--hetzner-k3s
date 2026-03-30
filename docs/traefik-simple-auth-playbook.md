---
Title: "Protect a Public App with Simple Traefik Basic Auth"
Slug: "traefik-simple-auth-playbook"
Short: "Add a shared-password gate in front of a public app using Traefik Middleware and a single-key htpasswd Secret."
Topics:
- traefik
- ingress
- auth
- kubernetes
- deployment
- gitops
Commands:
- htpasswd
- kubectl
- curl
- git
Flags: []
IsTopLevel: true
IsTemplate: false
ShowPerDefault: true
SectionType: Tutorial
---

## What This Page Covers

This page explains the simplest reliable way to put a password in front of a public app in this cluster.

The intended use case is:

- the app is already public over HTTPS
- you do not need per-user identities yet
- you want to share it with a few people
- you want a real auth gate, not just an obscure URL

The concrete example is `pretext-trace`, but the goal is to define a reusable operator pattern for any small public tool.

## When To Use This Pattern

Use this pattern when:

- the app should not be anonymous-public
- a shared password is acceptable
- the app does not need Keycloak yet
- you want the auth layer to live entirely in ingress, not inside the app

Do not use this pattern when:

- you need per-user identity
- you need audit trails
- you need logout/session semantics
- you already know the app belongs behind Keycloak

The mental model is:

```text
browser
  -> ingress
    -> Traefik Middleware basicAuth
      -> app Service
        -> app Pod
```

## The Important Constraint

Traefik `basicAuth` is stricter than it first appears.

The working Secret shape for this cluster is:

- Kubernetes `Secret`
- `type: Opaque`
- exactly one credentials key
- that key should be named `users`
- the value should be one or more htpasswd lines

This matters because a more elaborate secret-rendering path can look correct in Kubernetes while still failing in Traefik. During the `pretext-trace` rollout, a Vault/VSO-generated secret included extra keys such as `_raw`, and Traefik rejected it.

Treat this as the operator rule:

- image-pull secrets can be Vault/VSO-backed
- simple Traefik `basicAuth` secrets should be plain one-key Secrets unless you have already proven a richer renderer preserves the exact Traefik shape

## The Four Objects You Need

For a normal app, the minimum GitOps bundle is:

1. a `Secret` that contains the htpasswd lines
2. a Traefik `Middleware` that points at that Secret
3. an `Ingress` annotation that attaches the Middleware
4. the app `Service` and `Deployment` that already existed before auth

The auth-specific chain is:

```text
Secret(users)
  -> Middleware.spec.basicAuth.secret
    -> Ingress annotation
      -> requests challenge before reaching the app
```

## Step 1: Generate the htpasswd Line

Use bcrypt, not plaintext.

Example:

```bash
htpasswd -nbB friend trace-friends-2026
```

Example output:

```text
friend:$2y$05$...
```

What matters:

- the whole `user:hash` line goes into the Secret
- you can include multiple users by putting one htpasswd line per row

## Step 2: Create the Secret

The safe pattern is a static GitOps-managed Secret with a single `users` key.

Example:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-app-basic-auth
  annotations:
    argocd.argoproj.io/sync-wave: "0"
type: Opaque
stringData:
  users: |
    friend:$2y$05$exampleexampleexampleexampleexampleexampleexample
```

Why this shape matters:

- Traefik reads one credentials payload
- extra keys are risky
- `Opaque` is fine because this is not a Docker registry auth secret

The working live example in this repo is:

- [secret-basic-auth.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/pretext-trace/secret-basic-auth.yaml)

## Step 3: Create the Traefik Middleware

Use the `traefik.io/v1alpha1` `Middleware` CRD and point it at the Secret by name.

Example:

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: my-app-basic-auth
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  basicAuth:
    secret: my-app-basic-auth
```

The working live example is:

- [middleware-basic-auth.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/pretext-trace/middleware-basic-auth.yaml)

## Step 4: Attach the Middleware to the Ingress

The `Ingress` must reference the Middleware using the namespace-prefixed Traefik annotation form:

```yaml
metadata:
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: my-namespace-my-app-basic-auth@kubernetescrd
```

This part is easy to get wrong. The reference is not just the middleware name. It is:

```text
<namespace>-<middleware-name>@kubernetescrd
```

The working live example is:

- [ingress.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/pretext-trace/ingress.yaml)

## Step 5: Put the Files in the Kustomize Package

Make sure the package includes the auth files in its `kustomization.yaml`.

Typical order:

- namespace
- service account
- secret
- middleware
- deployment
- service
- ingress

The exact order is less important than the sync waves, but the package should still read coherently.

## Step 6: Apply or Sync the App

If the Argo `Application` already exists, a normal GitOps merge is enough.

If it is a brand-new app, remember the one-time bootstrap:

```bash
kubectl apply -f gitops/applications/<app>.yaml
kubectl -n argocd annotate application <app> argocd.argoproj.io/refresh=hard --overwrite
```

## Step 7: Validate the Auth Path

Check both the authenticated and unauthenticated paths.

Expected behavior:

- without credentials: `401 Unauthorized`
- with correct credentials: app responds normally

Example:

```bash
curl -i https://my-app.example.com/health
curl -i -u 'friend:trace-friends-2026' https://my-app.example.com/health
```

The healthy target state is:

```text
GET /health without auth  -> 401
GET /health with auth     -> 200
```

## Troubleshooting

### The browser gets `404` or the app loads without a password prompt

What it usually means:

- the Ingress is not actually referencing the Middleware you think it is

Check:

```bash
kubectl get ingress -A
kubectl -n <namespace> get ingress <name> -o yaml
kubectl -n <namespace> get middleware
```

Pay special attention to the annotation spelling:

```text
<namespace>-<middleware-name>@kubernetescrd
```

### Traefik logs complain about basic auth credential loading

What it usually means:

- the Secret shape is wrong

Check Traefik logs:

```bash
kubectl -n kube-system logs deploy/traefik --tail=200 | rg "basic auth|basicAuth|secret"
```

If the error mentions multiple elements or an unexpected payload count, the Secret probably contains extra keys. Replace it with a one-key `users` Secret.

### The Secret exists, but Traefik still ignores it

Check the Middleware object itself:

```bash
kubectl -n <namespace> get middleware <name> -o yaml
kubectl explain middleware.spec.basicAuth
```

Make sure:

- the CRD apiVersion is `traefik.io/v1alpha1`
- `spec.basicAuth.secret` names the Secret exactly
- the Middleware is in the same namespace as the Ingress

### Vault/VSO generated the Secret, but Traefik rejects it

This is the exact failure that happened for `pretext-trace`.

Safe response:

- stop trying to force the generated secret into Traefik immediately
- switch to a static one-key `users` Secret for the auth gate
- keep Vault/VSO for image-pull or app runtime secrets instead

That is the current recommended cluster pattern unless and until a Vault rendering path is proven to emit the exact Traefik-compatible shape.

## Recommended Operator Decision

Use this rule of thumb:

- friend-sharing public tool: Traefik basic auth
- internal app with real user accounts: Keycloak

That keeps the simple case simple and avoids dragging a small demo service into a heavier identity stack too early.

## Related Files

- [source-app-deployment-infrastructure-playbook.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/source-app-deployment-infrastructure-playbook.md)
- [app-packaging-and-gitops-pr-standard.md](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/app-packaging-and-gitops-pr-standard.md)
- [secret-basic-auth.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/pretext-trace/secret-basic-auth.yaml)
- [middleware-basic-auth.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/pretext-trace/middleware-basic-auth.yaml)
- [ingress.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/pretext-trace/ingress.yaml)

---
Title: "Use Kustomize Generated Config To Trigger Rollouts"
Slug: "kustomize-generated-config-rollout-pattern"
Short: "Refactor app config in Kustomize packages from handwritten ConfigMaps and subPath mounts to generated config that naturally rolls Deployments."
Topics:
- kustomize
- kubernetes
- argocd
- gitops
- configmap
- deployment
Commands:
- kubectl
- git
Flags: []
IsTopLevel: true
IsTemplate: false
ShowPerDefault: true
SectionType: Tutorial
---

## What This Page Covers

This page explains a specific deployment pattern we now want to standardize in this repository:

- config files should live as normal files in the Kustomize package
- Kustomize should generate the `ConfigMap`
- the generated ConfigMap name should change when config changes
- the Deployment should reference the logical ConfigMap name
- Kubernetes should roll the pod automatically when config changes

This is the right pattern for applications whose configuration is read at startup and does not need hot reload semantics.

The concrete motivating example is:

- `gitops/kustomize/wesen-os`

## The Problem This Solves

The failure mode looks like this:

1. a GitOps PR updates a `ConfigMap`
2. Argo shows `Synced`
3. the live application still serves the old config
4. an operator has to run `kubectl rollout restart`

That usually happens when a package combines:

- handwritten inline `ConfigMap` data
- `subPath` mounts for individual files

`subPath` is convenient, but it does not give you the operational behavior most people assume for config refresh.

## The Better Pattern

Use Kustomize to generate the `ConfigMap` from source files:

```yaml
configMapGenerator:
  - name: my-app-config
    files:
      - config/app.yaml
      - config/feature-flags.json
```

Then keep the Deployment reference at the logical name:

```yaml
volumes:
  - name: app-config
    configMap:
      name: my-app-config
```

Kustomize rewrites that reference to the generated hashed name in the rendered output.

That means:

```text
config file changes
  -> generated ConfigMap name changes
  -> rendered Deployment changes
  -> pod template changes
  -> Kubernetes rolls the Deployment
```

## Why This Works

Kustomize-generated resource names incorporate the generated content.

So if:

- `config/app.yaml` changes

then:

- `my-app-config-abc123` becomes something like `my-app-config-def456`

and because the Deployment volume reference is rewritten to the new generated name, the Deployment spec changes too.

That is the rollout trigger.

## When To Use This Pattern

Prefer this pattern when:

- the app reads config at startup
- a restart on config change is acceptable
- you want GitOps changes to produce rollout automatically
- you want a small amount of operator complexity

This is a good fit for:

- API services
- web backends
- UI hosts like `wesen-os`

## When Not To Use This Pattern

Do not treat this as a universal rule.

If the app needs true hot reload, the better pattern may be:

- mount the ConfigMap without `subPath`
- make the process reread or watch the files

That is a different runtime contract.

## Choosing Between The Main Config Patterns

Use this quick decision guide when designing or refactoring a Kustomize package.

### Pattern 1: Generated Config With Automatic Rollout

Choose this when:

- the process reads config at startup
- a restart is operationally acceptable
- you want config changes in Git to cause a predictable rollout
- you do not want to implement file watching or reload-safe runtime behavior

This is the default for most services in this repository.

### Pattern 2: True Hot Reload Without `subPath`

Choose this only when the application genuinely needs live config updates without a pod restart.

That usually means all of the following are true:

- the config changes frequently enough that restarting is undesirable
- the process can reread config per request or watch files safely
- partial config refresh behavior is understood and tested
- operators know they are relying on runtime reload semantics, not rollout semantics

If you choose this pattern:

- mount the whole ConfigMap directory
- do not use `subPath` for the hot-reloaded files
- make the process reread or watch the files explicitly
- document the reload contract clearly

### Pattern 3: Manual Restart Or Manual Revision Bump

Choose this only as an intermediate step when:

- the package cannot yet be refactored cleanly
- the config shape is still unstable
- you need a short-term operational workaround

This is the least desirable steady-state pattern because it depends on people remembering an extra step after config changes.

## Decision Table

| Need | Best fit |
| --- | --- |
| Startup config, restart OK, want clean GitOps rollouts | Generated config with automatic rollout |
| Live config updates without restart | Hot reload without `subPath` |
| Temporary workaround while refactoring | Manual restart / manual revision bump |

## Recommended Mount Shape

If your app already expects files under one directory, mount the whole directory:

```yaml
volumeMounts:
  - name: app-config
    mountPath: /config
    readOnly: true
```

Then pass the file paths explicitly to the process:

```text
/config/app.yaml
/config/feature-flags.json
```

This keeps the runtime contract simple and avoids the worst `subPath` surprise.

## Concrete `wesen-os` Example

The refactor for `wesen-os` uses:

- generated config inputs:
  - `gitops/kustomize/wesen-os/config/profiles.runtime.yaml`
  - `gitops/kustomize/wesen-os/config/federation.registry.json`
- `configMapGenerator` in:
  - `gitops/kustomize/wesen-os/kustomization.yaml`
- directory mount in:
  - `gitops/kustomize/wesen-os/deployment.yaml`

The current process flags still point to:

- `/config/profiles.runtime.yaml`
- `/config/federation.registry.json`

So the runtime contract remains the same while rollout behavior improves.

## Validation Checklist

Before merging a refactor like this, validate:

```bash
kubectl kustomize gitops/kustomize/<app>
```

You want to see:

- generated ConfigMap name with a hash suffix
- Deployment volume reference rewritten to that generated name
- container args still point to the expected config file paths
- no unwanted manifest drift outside config handling

After merge, validate:

```bash
kubectl -n argocd get application <app>
kubectl -n <namespace> rollout status deploy/<app>
```

Then make a config-only change and prove the rollout happens without a manual restart.

## Reusable Checklist For Future Packages

When applying this pattern to another package in this repository:

1. Move inline ConfigMap data into real files under the Kustomize package.
2. Replace the handwritten ConfigMap resource with `configMapGenerator`.
3. Preserve any annotations the generated object still needs, such as sync-wave ordering.
4. Keep the logical ConfigMap name stable in the Deployment manifest.
5. Mount the config as a directory when the process expects multiple files.
6. Keep the process flags or env vars pointing at stable in-container file paths.
7. Render the package with `kubectl kustomize` and confirm the generated name has a hash suffix.
8. Confirm Kustomize rewrites the Deployment volume reference to the generated name.
9. After merge, make one config-only change and prove that Kubernetes rolls the Deployment automatically.
10. Add or update operator-facing docs if the package is important enough that people will troubleshoot it directly.

## `subPath` Is Not Always Wrong

This page is not saying “never use `subPath`.”

It is saying:

- do not rely on `subPath` if your operational expectation is “ConfigMap change should show up automatically in a running pod”

If that is your expectation, either:

1. use generated config to trigger rollout, or
2. design true hot reload explicitly

## Practical Rule For This Repo

For packages in this repository, default to:

- Kustomize-generated config
- automatic rollout on config change

Only choose live hot reload when the application explicitly needs it and is implemented to support it.

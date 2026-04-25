---
Title: Diary
Ticket: HK3S-0023
Status: active
Topics:
    - observability
    - monitoring
    - prometheus
    - grafana
    - traefik
    - k3s
    - argocd
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: gitops/applications/monitoring-extras.yaml
      Note: Argo CD application for repo-owned PrometheusRule and PodMonitor resources
    - Path: gitops/applications/monitoring.yaml
      Note: Argo CD Helm application for kube-prometheus-stack
    - Path: gitops/applications/traefik-observability.yaml
      Note: Argo CD application for K3s Traefik HelmChartConfig observability settings
    - Path: gitops/kustomize/monitoring-extras/podmonitor-traefik.yaml
      Note: Prometheus Operator PodMonitor for built-in K3s Traefik metrics
    - Path: gitops/kustomize/monitoring-extras/prometheus-rule-hetzner-egress.yaml
      Note: Prometheus egress alert rules scoped to the real Hetzner eth0 NIC
    - Path: gitops/kustomize/traefik-observability/traefik-helmchartconfig.yaml
      Note: K3s HelmChartConfig enabling JSON access logs and Prometheus labels
ExternalSources: []
Summary: "Chronological implementation notes for adding Prometheus, Grafana, Alertmanager, node-exporter, Traefik metrics scraping, and Traefik JSON access logs to the Hetzner K3s GitOps platform."
LastUpdated: 2026-04-25T09:18:00-04:00
WhatFor: "Resume or review HK3S-0023 observability work without re-discovering decisions, commands, failures, and validation state."
WhenToUse: "Use before changing monitoring manifests, applying Argo CD observability applications, or debugging Prometheus/Traefik metrics on this cluster."
---

# Diary

## Goal

Record the implementation of host-level Hetzner egress monitoring and ingress/application attribution for the current single-node K3s + Argo CD platform.

## Step 1: Create the ticket and GitOps observability manifests

This step turned the monitoring plan into repo-owned Argo CD manifests. The implementation follows the current repository convention: each long-lived component gets an `Application` under `gitops/applications/`, while repo-owned Kubernetes resources live under `gitops/kustomize/<name>/`.

The first pass deliberately avoids a public Grafana ingress. Prometheus/Grafana/Alertmanager are installed privately in the `monitoring` namespace, with access expected through `kubectl port-forward` until we decide on authentication and exposure policy.

### Prompt Context

**User prompt (verbatim):** "Ok, crate a new docmgr ticket to do 1-4. then do it and apply it. commit at appropriate intervals, keep a detailed diary."

**Assistant interpretation:** Create a docmgr ticket for the four planned observability steps, implement the GitOps manifests, apply them to the live cluster, commit in focused chunks, and keep this diary current.

**Inferred user intent:** Add production-useful bandwidth monitoring and attribution while preserving the repository's GitOps/documentation workflow.

**Commit (code):** pending — manifest and ticket files are created locally before the first focused commit.

### What I did

- Created docmgr ticket `HK3S-0023` titled `Add Prometheus and Traefik observability for Hetzner egress`.
- Created this diary document under the ticket workspace.
- Added task items for:
  - kube-prometheus-stack installation
  - Hetzner `eth0` egress alerting
  - Traefik metrics scraping
  - Traefik JSON access logs
- Added `gitops/applications/monitoring.yaml` to install `kube-prometheus-stack` chart version `84.0.0` from `prometheus-community`.
- Added `gitops/applications/monitoring-extras.yaml` for repo-owned Prometheus Operator resources.
- Added `gitops/kustomize/monitoring-extras/prometheus-rule-hetzner-egress.yaml` with `HighHetznerEgress24h` and `VeryHighHetznerEgressRate` alerts scoped to `device="eth0"`.
- Added `gitops/kustomize/monitoring-extras/podmonitor-traefik.yaml` to scrape built-in K3s Traefik metrics from the `metrics` container port.
- Added `gitops/applications/traefik-observability.yaml` and `gitops/kustomize/traefik-observability/traefik-helmchartconfig.yaml` to enable JSON access logs and explicit Prometheus label options for K3s-managed Traefik.
- Validated local rendering with:
  - `kubectl kustomize gitops/kustomize/monitoring-extras`
  - `kubectl kustomize gitops/kustomize/traefik-observability`
  - `kubectl apply --dry-run=client -f gitops/applications/monitoring.yaml -f gitops/applications/monitoring-extras.yaml -f gitops/applications/traefik-observability.yaml`
  - `kubectl apply --dry-run=client -f /tmp/traefik-observability.yaml`

### Why

- `kube-prometheus-stack` gives us Prometheus, Grafana, Alertmanager, kube-state-metrics, Prometheus Operator CRDs, and node-exporter in one maintained package.
- The node's real Hetzner egress interface is `eth0`; using `eth0` avoids double-counting loopback, flannel, CNI bridge, Docker bridge, veth, and Tailscale interfaces.
- Traefik is the live ingress controller in this K3s cluster, so nginx-ingress metrics would not match reality.
- A `PodMonitor` avoids modifying the Traefik `Service` just to expose metrics.
- JSON access logs are needed for path/IP/user-agent attribution that Prometheus metrics cannot provide.

### What worked

- The cluster inspection showed all existing Argo CD Applications healthy before starting.
- Node interface inspection via `kubectl debug node/k3s-demo-1 ... ip route show default` confirmed the default route uses `eth0`.
- Traefik already had `--metrics.prometheus=true` and a named `metrics` container port on `9100`, so only a `PodMonitor` was needed for scraping.
- Kustomize render and client-side dry-run validation succeeded for the repo-owned manifests and Argo CD Application manifests.

### What didn't work

- `helm` is not installed in this local environment, so I could not run `helm search repo` locally. The exact error was:

  ```text
  /bin/bash: line 1: helm: command not found
  ```

- To choose the chart version, I used a web search result showing `kube-prometheus-stack 84.0.0` as the current Artifact Hub version instead of local Helm metadata.

### What I learned

- This cluster is already exposing Traefik Prometheus metrics internally; the missing piece is discovery by Prometheus Operator.
- The live K3s node has many overlay/virtual devices, so egress PromQL must be strict (`device="eth0"`) rather than broad.
- The current repo does not have an app-of-apps pattern for auto-discovering new `gitops/applications/*.yaml`; each new Application still needs a one-time `kubectl apply`.

### What was tricky to build

- The main ordering constraint is that `monitoring-extras` contains `PrometheusRule` and `PodMonitor` CRs whose CRDs are installed by `kube-prometheus-stack`. Applying `monitoring-extras` before `monitoring` is healthy may fail or leave Argo in a temporary comparison/sync error state. The intended apply sequence is therefore: monitoring first, wait for CRDs/operator, then monitoring-extras.
- K3s-managed Traefik is not configured by editing a Deployment directly; it is configured by a `helm.cattle.io/v1` `HelmChartConfig` named `traefik` in `kube-system`. This lets K3s reconcile the generated Helm release without fighting the built-in controller.

### What warrants a second pair of eyes

- The `kube-prometheus-stack` chart version `84.0.0` should be reviewed before long-term pinning, because it was selected without local Helm tooling.
- The Traefik `additionalArguments` list should be checked after apply to ensure it appends to, rather than accidentally replaces, the arguments generated by the K3s Traefik chart.
- The alert thresholds (`500 GiB/24h` and sustained `200 Mbit/s`) are operational guesses and should be tuned against Hetzner traffic allowances and expected workload behavior.

### What should be done in the future

- Add Loki/Promtail or another log backend to persist and query the Traefik JSON access logs.
- Decide whether Grafana should remain port-forward-only or get a protected public ingress.
- Add dashboards for host egress, Traefik service bytes/requests, and later log-derived top IP/path/user-agent views.

### Code review instructions

- Start with `gitops/applications/monitoring.yaml` and verify the Helm chart, namespace, storage, and selector settings.
- Then review `gitops/kustomize/monitoring-extras/` for the `eth0` PromQL and Traefik `PodMonitor` selector.
- Finally review `gitops/kustomize/traefik-observability/traefik-helmchartconfig.yaml` for Traefik access log and metrics arguments.
- Validate locally with:

  ```bash
  kubectl kustomize gitops/kustomize/monitoring-extras
  kubectl kustomize gitops/kustomize/traefik-observability
  kubectl apply --dry-run=client -f gitops/applications/monitoring.yaml \
    -f gitops/applications/monitoring-extras.yaml \
    -f gitops/applications/traefik-observability.yaml
  ```

### Technical details

Key PromQL:

```promql
sum by (instance) (
  rate(node_network_transmit_bytes_total{device="eth0"}[5m])
) * 8
```

```promql
sum by (instance) (
  increase(node_network_transmit_bytes_total{device="eth0"}[24h])
) / 1024 / 1024 / 1024
```

Expected apply sequence:

```bash
kubectl apply -f gitops/applications/monitoring.yaml
kubectl -n argocd get application monitoring
kubectl apply -f gitops/applications/monitoring-extras.yaml
kubectl apply -f gitops/applications/traefik-observability.yaml
```

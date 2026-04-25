---
Title: Diary
Ticket: HK3S-0024
Status: active
Topics:
    - observability
    - monitoring
    - grafana
    - loki
    - traefik
    - argocd
    - k3s
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: docs/grafana-keycloak-access-playbook.md
      Note: Documents Keycloak OIDC plan for Grafana access
    - Path: gitops/applications/loki.yaml
      Note: Loki/Promtail Argo CD Helm application
    - Path: gitops/applications/monitoring.yaml
      Note: Adds Loki Grafana datasource
    - Path: gitops/kustomize/monitoring-extras/grafana-dashboard-hetzner-egress.yaml
      Note: Grafana dashboard for eth0 Hetzner egress
    - Path: gitops/kustomize/monitoring-extras/grafana-dashboard-traefik-attribution.yaml
      Note: Grafana dashboard for Traefik metrics and Loki log attribution
ExternalSources: []
Summary: Implementation diary for Grafana dashboards, Loki/Promtail log retention, and Grafana Keycloak access planning.
LastUpdated: 2026-04-25T10:35:00-04:00
WhatFor: Resume or review the HK3S-0024 logging/dashboard follow-up after HK3S-0023.
WhenToUse: Use when changing Grafana dashboards, Loki/Promtail, or Grafana authentication exposure.
---


# Diary

## Goal

Add the next observability layer after HK3S-0023: practical Grafana dashboards and retained Traefik access logs through Loki/Promtail. Also document how Grafana can be exposed through Keycloak OIDC later.

## Step 1: Add dashboards, Loki app, and Keycloak access plan

This step adds the GitOps scaffolding for the two requested follow-ups: Grafana dashboards and a Loki/Promtail log backend. The dashboards are delivered as Grafana sidecar ConfigMaps in the existing `monitoring-extras` Kustomize package so they ride with the Prometheus rules and Traefik PodMonitor.

The Loki setup uses the `grafana/loki-stack` chart with Grafana and Prometheus disabled because this cluster already has Grafana and Prometheus from `kube-prometheus-stack`. Promtail is enabled to ship Kubernetes container logs to Loki, including the JSON Traefik access logs enabled in HK3S-0023.

### Prompt Context

**User prompt (verbatim):** "do, 1 + 2

for 5. can we configure keycloak for access?"

**Assistant interpretation:** Implement recommended follow-up items 1 and 2: Grafana dashboards and Loki/Promtail log retention. Also answer/design whether Grafana public access can be protected with Keycloak.

**Inferred user intent:** Move from raw metrics/log generation to usable dashboards and retained log attribution, while planning authenticated Grafana access instead of exposing it anonymously.

**Commit (code):** pending — initial GitOps and documentation files are staged for the first focused commit.

### What I did

- Created ticket `HK3S-0024` and this diary.
- Added `gitops/applications/loki.yaml` for the `grafana/loki-stack` chart in namespace `logging`.
- Configured Loki persistence with `local-path` and 7-day retention intent.
- Enabled Promtail and added a defensive Traefik pipeline `replace` stage for token/authorization/cookie/secret-like fields.
- Added Loki as a Grafana datasource in `gitops/applications/monitoring.yaml` using `grafana.additionalDataSources`.
- Added two Grafana dashboard ConfigMaps to `gitops/kustomize/monitoring-extras/`:
  - `grafana-dashboard-hetzner-egress.yaml`
  - `grafana-dashboard-traefik-attribution.yaml`
- Updated `gitops/kustomize/monitoring-extras/kustomization.yaml` to include the dashboards.
- Added `docs/grafana-keycloak-access-playbook.md` explaining how Grafana can be exposed with Keycloak OIDC later.
- Validated local rendering and client-side dry-runs:

  ```bash
  kubectl kustomize gitops/kustomize/monitoring-extras
  kubectl apply --dry-run=client -f gitops/applications/loki.yaml -f gitops/applications/monitoring.yaml
  kubectl apply --dry-run=client -f /tmp/monitoring-extras.yaml
  ```

### Why

- Dashboards make the Prometheus metrics added in HK3S-0023 immediately usable by operators.
- Loki/Promtail gives retained access-log data, which is necessary for attribution questions such as top hosts, paths, and user agents by bytes over time.
- Grafana access should be solved with Keycloak OIDC rather than a public unauthenticated ingress.

### What worked

- Kustomize rendered the monitoring extras package with the new dashboard ConfigMaps.
- The Argo CD Application manifests passed client-side dry-run.
- The monitoring extras resources passed client-side dry-run, although one API response body read hit a transient `context deadline exceeded` while the resources still validated.

### What didn't work

- The local environment still has no Helm CLI, so chart validation is through Argo CD/Kubernetes dry-run and live apply rather than local `helm template`.
- The `loki-stack`/Promtail pipeline syntax needs live validation after Argo renders the Helm chart.

### What I learned

- The Grafana sidecar dashboard path is the lowest-friction way to add repo-owned dashboards because kube-prometheus-stack already includes the Grafana sidecar convention.
- Keycloak access should be a separate implementation step because it needs a Keycloak client, a client secret in Vault, VSO resources in the monitoring namespace, and a Grafana ingress decision.

### What was tricky to build

- Loki chart choice matters. The modern Loki chart has more deployment modes and more required storage/schema decisions; for this small single-node cluster, `loki-stack` is a simpler first step that includes Promtail and avoids replacing the existing Grafana/Prometheus stack.
- Dashboard LogQL panels depend on Traefik JSON fields and Loki label names. These should be treated as initial dashboards that may need tuning after live log inspection.

### What warrants a second pair of eyes

- Review the Promtail redaction pipeline once live. If the chart ignores the snippet or the regex is wrong, use a simpler Promtail relabel/pipeline config or move redaction into a future Alloy pipeline.
- Review whether 7 days and 10Gi are acceptable defaults for Loki on this single-node server.

### What should be done in the future

- Implement the Keycloak Grafana access playbook once the desired realm, groups, and hostname are confirmed.
- Consider moving from Promtail to Grafana Alloy in the future because Promtail is in maintenance/deprecation path.

### Code review instructions

- Start with `gitops/applications/loki.yaml` and verify chart values.
- Review `gitops/applications/monitoring.yaml` for the Loki datasource.
- Review the dashboard ConfigMaps under `gitops/kustomize/monitoring-extras/`.
- Review `docs/grafana-keycloak-access-playbook.md` for the OIDC plan.

### Technical details

Important datasource URL:

```text
http://loki.logging.svc.cluster.local:3100
```

Prometheus dashboard query for host egress:

```promql
sum by (instance) (rate(node_network_transmit_bytes_total{device="eth0"}[5m])) * 8
```

Example LogQL panel query:

```logql
topk(20, sum by (RequestHost) (sum_over_time({namespace="kube-system", app_kubernetes_io_name="traefik"} | json | unwrap OriginContentSize [1h])))
```

## Step 2: Confirm Grafana rollout and handle Loki StatefulSet diff noise

During live rollout, the user noticed what looked like a hanging Grafana pod. I inspected the Grafana Deployment, ReplicaSets, and pod events. Grafana had already converged: there was exactly one desired/current/ready Grafana pod, old ReplicaSets were scaled to zero, and the only warning was a short startup readiness failure before Grafana began listening on port 3000.

The remaining unhealthy-looking item was not Grafana; it was the Loki Argo CD Application showing `OutOfSync` while the Loki StatefulSet and Promtail DaemonSet were healthy. The Loki chart/live StatefulSet comparison differs in server-defaulted StatefulSet/PVC-template fields, so I added an Argo CD `ignoreDifferences` rule for the Loki StatefulSet's immutable/defaulted PVC template and retention-policy fields.

### Prompt Context

**User prompt (verbatim):** "one of the grafana pods seems to be hanging?"

**Assistant interpretation:** Inspect the apparent hang, determine whether Grafana is actually stuck, and fix any rollout/sync issue that remains.

**Inferred user intent:** Keep the observability rollout clean and avoid leaving stuck pods or unhealthy Argo CD Applications.

**Commit (code):** pending — Loki `ignoreDifferences` fix is staged for the next commit.

### What I did

- Checked Grafana pods and ReplicaSets:

  ```bash
  kubectl -n monitoring get pods,rs -l app.kubernetes.io/name=grafana -o wide
  kubectl -n monitoring describe deploy monitoring-grafana
  ```

- Confirmed current Grafana state:

  ```text
  monitoring-grafana-5d4dcf996f-mwsqh  3/3  Running
  ```

- Checked Argo CD Application state:

  ```text
  loki                OutOfSync  Healthy
  monitoring          Synced     Healthy
  monitoring-extras   Synced     Healthy
  ```

- Used the Argo CD CLI inside the `argocd-server` pod to inspect the Loki app and generated manifests.
- Found the live Loki StatefulSet was healthy, but Argo CD still considered it `OutOfSync`.
- Added `ignoreDifferences` to `gitops/applications/loki.yaml` for:
  - `/spec/persistentVolumeClaimRetentionPolicy`
  - `/spec/volumeClaimTemplates`

### Why

- Grafana was not actually stuck; it had rolled forward after the Loki datasource/dashboard change.
- StatefulSet volume claim templates are effectively immutable and often pick up Kubernetes defaulted fields such as `volumeMode` or retention policy shape. For a single-node Loki install, those defaulted fields are not meaningful drift.

### What worked

- Grafana readiness recovered normally after startup.
- Loki and Promtail pods were running.
- The Argo CD CLI showed the Loki sync operation had succeeded even though resource comparison still showed the StatefulSet as `OutOfSync`.

### What didn't work

- `argocd app diff loki` returned no human-readable diff even though the Application resource list showed the StatefulSet as OutOfSync. I used `argocd app manifests loki` plus `kubectl get statefulset loki -o json` to compare the likely defaulted fields.

### What I learned

- The Loki Application health can be green while sync status is noisy due to StatefulSet/PVC template comparison details.
- The visible Grafana warning was transient startup readiness noise, not a hanging rollout.

### What was tricky to build

- The confusing part was that the user-visible symptom mentioned Grafana, but the actual remaining Argo issue was Loki. Checking both Kubernetes workload health and Argo CD sync status prevented fixing the wrong component.

### What warrants a second pair of eyes

- The `ignoreDifferences` rule ignores the full Loki StatefulSet `volumeClaimTemplates`; that is acceptable for this current single PVC setup but should be revisited if Loki storage topology changes.

### What should be done in the future

- If Loki storage requirements change, remove or narrow the ignore rule and recreate/migrate the StatefulSet/PVC intentionally.

### Code review instructions

- Review `gitops/applications/loki.yaml`, especially the `ignoreDifferences` block.
- Validate with:

  ```bash
  kubectl -n argocd get applications loki monitoring monitoring-extras
  kubectl -n logging get pods
  ```

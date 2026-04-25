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

## Step 2: Fix Grafana init chown permissions during first rollout

The first live apply installed most of the monitoring stack successfully, but the Grafana rollout got stuck on a replacement pod whose `init-chown-data` container could not recursively chown all persisted directories. This was caught before applying the dependent `monitoring-extras` application, which was intentional because those resources depend on Prometheus Operator CRDs from the monitoring stack.

The fix keeps Grafana persistence enabled and broadens the init container's Linux capabilities just enough for recursive ownership repair on the local-path volume. This is safer for the immediate rollout than deleting the PVC or disabling persistence after data has already been initialized.

### Prompt Context

**User prompt (verbatim):** (same as Step 1; user also reported live failure: `Back-off restarting failed container init-chown-data in pod monitoring-grafana-7d8f8999c6-xg2nf_monitoring(95485de4-e218-489a-ae32-949662e90f5a)`)

**Assistant interpretation:** Debug and fix the failed Grafana init container so the monitoring Application can become healthy before proceeding.

**Inferred user intent:** Continue the requested apply, but handle rollout failures transparently and record what changed.

**Commit (code):** pending — Grafana initChownData capability fix is staged for a focused follow-up commit.

### What I did

- Inspected the failing pod with:

  ```bash
  kubectl -n monitoring describe pod monitoring-grafana-7d8f8999c6-xg2nf
  kubectl -n monitoring logs monitoring-grafana-7d8f8999c6-xg2nf -c init-chown-data --previous
  kubectl -n monitoring get pods,pvc
  kubectl -n monitoring get deploy monitoring-grafana -o yaml
  ```

- Observed that Prometheus, Alertmanager, kube-state-metrics, node-exporter, and the operator were already running.
- Updated `gitops/applications/monitoring.yaml` to configure `grafana.initChownData.securityContext.capabilities.add` with `CHOWN`, `DAC_OVERRIDE`, and `FOWNER` while keeping `drop: [ALL]` and root execution for the init container.
- Validated the changed Application manifest with:

  ```bash
  kubectl apply --dry-run=client -f gitops/applications/monitoring.yaml
  ```

### Why

- The error came from the init container while recursively changing ownership of the Grafana data directory on a `local-path` PVC.
- The rendered init container was root with `CHOWN` but had dropped all other capabilities; the failing directories required additional capability to traverse/override existing permissions during recursive ownership repair.
- Keeping the init container constrained and only adding `DAC_OVERRIDE` and `FOWNER` preserves the chart's intended ownership model without broad privileged mode.

### What worked

- The failing container logs clearly identified the permission problem:

  ```text
  chown: /var/lib/grafana/csv: Permission denied
  chown: /var/lib/grafana/pdf: Permission denied
  chown: /var/lib/grafana/png: Permission denied
  ```

- The live stack had enough components running to show that the chart version and core CRD/operator install succeeded.

### What didn't work

- Waiting alone did not converge the rollout; Grafana stayed in `Init:CrashLoopBackOff` and the Argo CD Application stayed `Synced Progressing`.

### What I learned

- The kube-prometheus-stack Grafana subchart can create a running first pod and still fail a later rollout if persisted directories have permissions that the init chown container cannot traverse with only the `CHOWN` capability.
- On this cluster, local-path persistence plus a restricted chown init container needs slightly broader ownership-repair capabilities.

### What was tricky to build

- The cluster had both one running old Grafana pod and one failing new Grafana pod. That made the service partially usable while the Deployment health was still bad. The correct signal was the Argo CD Application health and Deployment rollout state, not just whether any Grafana pod was running.

### What warrants a second pair of eyes

- Review whether adding `DAC_OVERRIDE` and `FOWNER` to the init container is acceptable for this cluster's security posture.
- If strict pod security becomes a priority, consider pre-provisioning/chowning the local-path directory outside the pod or replacing Grafana persistence with a storage backend that preserves expected ownership.

### What should be done in the future

- If this fix does not converge, the next fallback is to inspect the local-path backing directory on the node and repair/delete only the Grafana PVC data after confirming there is no important dashboard state.

### Code review instructions

- Review the `grafana.initChownData.securityContext` block in `gitops/applications/monitoring.yaml`.
- After deploy, validate with:

  ```bash
  kubectl -n monitoring rollout status deploy/monitoring-grafana
  kubectl -n argocd get application monitoring
  ```

### Technical details

The failing pod was `monitoring-grafana-7d8f8999c6-xg2nf` in namespace `monitoring`. The stuck status was `Init:CrashLoopBackOff`, and the failed init container was `init-chown-data`.

## Step 3: Tighten Traefik access-log header policy after seeing Vault tokens

After enabling JSON access logs, validation immediately showed that `headers.defaultmode=keep` was too permissive for this cluster. Vault requests from in-cluster controllers include `X-Vault-Token`, and Traefik logged that header because only `Authorization`, `Cookie`, and `Set-Cookie` were explicitly dropped.

I changed the policy to `headers.defaultmode=drop` and then allowed only the attribution headers we actually need. This preserves user-agent and forwarded-client context without making arbitrary application or secret-bearing headers durable in ingress logs.

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Continue applying and validating the observability stack, and fix any operational or security issues found during validation.

**Inferred user intent:** Get useful ingress attribution without introducing avoidable secret leakage.

**Commit (code):** pending — header redaction hardening is staged for a focused follow-up commit.

### What I did

- Generated traffic with:

  ```bash
  curl -k -s -o /dev/null -w '%{http_code}\n' https://pretext.yolo.scapegoat.dev/
  ```

- Inspected Traefik logs with:

  ```bash
  kubectl -n kube-system logs deploy/traefik --since=2m | tail -20
  ```

- Observed JSON access logs were working, but also observed `request_X-Vault-Token` in logs for Vault traffic.
- Updated `gitops/kustomize/traefik-observability/traefik-helmchartconfig.yaml` from `headers.defaultmode=keep` to `headers.defaultmode=drop`.
- Explicitly kept only:
  - `User-Agent`
  - `X-Forwarded-For`
  - `X-Real-Ip`
  - `X-Forwarded-Host`
  - `X-Forwarded-Proto`
- Validated the Kustomize render and client-side apply dry-run.

### Why

- Ingress access logs should support attribution, but they must not become a secret sink.
- Default-keep headers are risky in a platform cluster because any workload/controller can use custom headers for credentials.
- The core attribution fields needed for this ticket are already present in Traefik's structured log fields (`ClientHost`, `RequestHost`, `RequestPath`, `ServiceName`, byte counts, status, durations), so only a small header allowlist is needed.

### What worked

- Traefik JSON logs were confirmed live after the HelmChartConfig rollout.
- A request to `pretext.yolo.scapegoat.dev` produced a structured access log with host, path, service, byte counts, status, and user-agent.

### What didn't work

- The initial header policy was unsafe. It logged `request_X-Vault-Token` values for Vault requests. This was corrected in Git before closing the ticket.

### What I learned

- Traefik's default structured fields are enough for most ingress attribution; keeping all headers is unnecessary and dangerous.
- Vault Secrets Operator traffic crosses the public Traefik ingress for `vault.yolo.scapegoat.dev`, so ingress logs can see Vault request headers unless explicitly configured not to.

### What was tricky to build

- The original user requirement asked to include `user_agent` and forwarded address information. The safe interpretation is not “keep all headers,” but “allowlist the specific non-secret headers required for attribution.”

### What warrants a second pair of eyes

- Operators should consider rotating Vault tokens or waiting for short-lived token expiry because some token values were emitted in Traefik logs during the brief validation window before this fix.
- Review whether `X-Forwarded-Host` and `X-Forwarded-Proto` need to be kept as headers, since Traefik also emits `RequestHost` and `RequestScheme` as structured fields.

### What should be done in the future

- When Loki/Promtail is added, include a log-scrubbing stage that drops any remaining `request_*Token*`, `request_*Authorization*`, and cookie-like fields defensively.

### Code review instructions

- Review only the header policy in `gitops/kustomize/traefik-observability/traefik-helmchartconfig.yaml`.
- After apply, generate one request and verify logs include `request_User-Agent` but do not include `request_X-Vault-Token`.

### Technical details

The key invariant is:

```text
--accesslog.fields.headers.defaultmode=drop
```

and only a small attribution allowlist is added back with `headers.names.*=keep`.

## Step 4: Apply monitoring extras, validate metrics, and close rollout tasks

After the Grafana rollout fix and Traefik header redaction fix were pushed, all three Argo CD Applications converged. The monitoring namespace now has Prometheus, Grafana, Alertmanager, kube-state-metrics, node-exporter, and Prometheus Operator running; the extras Application owns the Hetzner egress rule and Traefik PodMonitor; and the Traefik observability Application owns the K3s HelmChartConfig.

Validation confirmed the two critical telemetry paths: Prometheus can query `node_network_transmit_bytes_total{device="eth0"}` for host egress and can scrape Traefik through the `monitoring/traefik` PodMonitor target. Traefik JSON access logs also emit request attribution fields while the hardened header allowlist prevents `request_X-Vault-Token` from appearing in recent logs.

### Prompt Context

**User prompt (verbatim):** (same as Step 1)

**Assistant interpretation:** Finish the live apply and validate that the requested monitoring/attribution primitives are actually working in the cluster.

**Inferred user intent:** End with GitOps state reconciled, live resources healthy, and enough validation evidence for operational use.

**Commit (code):** `369826bb1c37edc524dc68d6cd28b7d6cee06282` — `feat(observability): add Hetzner egress monitoring`; `d233bd37d0ccb7588f7c5de26e0bc64454cf5ff2` — `fix(observability): unblock grafana pvc chown`; `bfb022a60b1525a8f0a4d6f9ec5a1dcf4f12c93b` — `fix(observability): redact traefik access log headers`

### What I did

- Applied and refreshed the Applications:

  ```bash
  kubectl apply -f gitops/applications/monitoring.yaml
  kubectl apply -f gitops/applications/monitoring-extras.yaml
  kubectl apply -f gitops/applications/traefik-observability.yaml
  kubectl -n argocd annotate application <app> argocd.argoproj.io/refresh=hard --overwrite
  ```

- Waited for Grafana and Traefik rollouts:

  ```bash
  kubectl -n monitoring rollout status deploy/monitoring-grafana --timeout=120s
  kubectl -n kube-system rollout status deploy/traefik --timeout=180s
  ```

- Validated Application health:

  ```bash
  kubectl -n argocd get applications monitoring monitoring-extras traefik-observability
  ```

  Result:

  ```text
  NAME                    SYNC STATUS   HEALTH STATUS
  monitoring              Synced        Healthy
  monitoring-extras       Synced        Healthy
  traefik-observability   Synced        Healthy
  ```

- Validated monitoring pods:

  ```bash
  kubectl -n monitoring get pods
  ```

  All monitoring pods were `Running`.

- Validated CR ownership:

  ```bash
  kubectl -n monitoring get prometheusrule hetzner-egress -o name
  kubectl -n monitoring get podmonitor traefik -o name
  ```

- Port-forwarded Prometheus and queried metrics/rules:

  ```bash
  kubectl -n monitoring port-forward svc/monitoring-prometheus 19090:9090
  curl 'http://127.0.0.1:19090/api/v1/query?query=node_network_transmit_bytes_total%7Bdevice%3D%22eth0%22%7D'
  curl 'http://127.0.0.1:19090/api/v1/query?query=traefik_service_requests_total'
  curl 'http://127.0.0.1:19090/api/v1/rules'
  ```

- Confirmed Prometheus target discovery includes:

  ```text
  up  monitoring/traefik  http://10.42.0.159:9100/metrics
  up  node-exporter       http://91.98.46.169:9100/metrics
  ```

- Generated a request to `https://pretext.yolo.scapegoat.dev/` and checked recent Traefik logs for header redaction:

  ```bash
  kubectl -n kube-system logs deploy/traefik --since=30s | grep -c 'request_X-Vault-Token'
  kubectl -n kube-system logs deploy/traefik --since=30s | grep -c 'request_User-Agent'
  ```

  Result: token field count `0`, user-agent field count non-zero.

### Why

- Applying only the Argo CD Applications is not enough; for this kind of change, the important proof is that Prometheus can query the exact host metric and scrape the intended ingress controller target.
- The Traefik log validation proves attribution data is being emitted without continuing the accidental Vault token header exposure found in Step 3.

### What worked

- `monitoring`, `monitoring-extras`, and `traefik-observability` all reached `Synced Healthy`.
- The Grafana hanging ReplicaSet resolved after Argo picked up the init container capability fix; the old ReplicaSets scaled to zero and `monitoring-grafana-74f8bb7cd9-8mm2b` ran `3/3`.
- Prometheus returned one result for `node_network_transmit_bytes_total{device="eth0"}`.
- Prometheus returned Traefik service request metrics after the PodMonitor target appeared.
- The `HighHetznerEgress24h` and `VeryHighHetznerEgressRate` rules appeared in Prometheus.
- Traefik restarted cleanly and retained the built-in K3s metrics arguments plus the new access-log/header arguments.

### What didn't work

- The first Prometheus query for Traefik immediately after applying `monitoring-extras` returned zero results because Prometheus had not yet reloaded target configuration. Waiting roughly one minute resolved this.
- `kubectl logs deploy/traefik` briefly printed `Found 2 pods, using pod/...` during rollout, which was expected while Kubernetes was replacing the Traefik pod.

### What I learned

- Prometheus Operator CR discovery is not instantaneous; after a PodMonitor is created, allow a short interval before concluding it failed.
- Argo CD can report `Synced Healthy` for the Application once it has reconciled, but validating metric queries and target health is still necessary.

### What was tricky to build

- The main rollout trap was sequencing and patience: Prometheus CRDs had to exist before applying `monitoring-extras`, Grafana needed a follow-up security context fix, and Prometheus needed a small reload window before showing the new Traefik target.
- The main security trap was that JSON access logs worked too well with default header retention. The final configuration intentionally favors a narrow attribution header allowlist.

### What warrants a second pair of eyes

- The brief pre-fix Traefik log window did include Vault token header fields. Those tokens are likely short-lived service/controller tokens, but an operator should decide whether any Vault token/accessor rotation or audit review is warranted.
- Alert thresholds still need operational tuning.

### What should be done in the future

- Add Loki/Promtail with defensive redaction to persist and query access logs safely.
- Build Grafana dashboards for host egress and Traefik service attribution.
- Decide whether to expose Grafana behind auth or keep it port-forward-only.

### Code review instructions

- Review commits in order:
  1. `369826b` for the initial architecture/manifests.
  2. `d233bd3` for the Grafana init chown fix.
  3. `bfb022a` for the access-log header redaction fix.
- Validate current state with:

  ```bash
  kubectl -n argocd get applications monitoring monitoring-extras traefik-observability
  kubectl -n monitoring get pods
  kubectl -n monitoring get prometheusrule hetzner-egress
  kubectl -n monitoring get podmonitor traefik
  kubectl -n kube-system get deploy traefik -o jsonpath='{.spec.template.spec.containers[0].args}' | jq -r '.[]' | grep accesslog
  ```

### Technical details

Current key queries:

```promql
sum by (instance) (rate(node_network_transmit_bytes_total{device="eth0"}[5m])) * 8
```

```promql
sum by (instance) (increase(node_network_transmit_bytes_total{device="eth0"}[24h])) / 1024 / 1024 / 1024
```

```promql
sum by (service, code, method) (rate(traefik_service_requests_total[5m]))
```

## Step 5: Move VSO VaultConnections off the public Traefik hostname

After investigating why Vault token headers appeared in Traefik access logs, the source was clear: several in-cluster Vault Secrets Operator `VaultConnection` resources still pointed at `https://vault.yolo.scapegoat.dev`. That forced routine VSO refresh traffic through the public ingress path even though Vault is available as an internal Kubernetes service.

This follow-up changes those in-cluster VSO connections to `http://vault.vault.svc.cluster.local:8200` and updates the operator documentation so future app packages do not repeat the public-hostname pattern. The public Vault hostname remains valid for human/operator access from outside the cluster; it should not be used for Kubernetes controllers that can reach the service DNS name directly.

### Prompt Context

**User prompt (verbatim):** "update the public traefik hostnames for vault to use the internal ones."

**Assistant interpretation:** Replace the remaining VSO VaultConnection resources that route through Traefik with internal Vault service addresses and apply the change.

**Inferred user intent:** Stop VSO-to-Vault controller traffic from traversing Traefik and eliminate this class of ingress-log secret exposure.

**Commit (code):** pending — VaultConnection and documentation changes are being committed as a focused follow-up.

### What I did

- Updated these manifests from `https://vault.yolo.scapegoat.dev` to `http://vault.vault.svc.cluster.local:8200`:
  - `gitops/kustomize/draft-review/vault-connection.yaml`
  - `gitops/kustomize/hair-booking/vault-connection.yaml`
  - `gitops/kustomize/keycloak/vault-connection.yaml`
  - `gitops/kustomize/smailnail/vault-connection.yaml`
- Set `skipTLSVerify: true` consistently for the internal HTTP service connection shape.
- Updated documentation:
  - `docs/app-runtime-secrets-and-identity-provisioning-playbook.md`
  - `docs/app-packaging-and-gitops-pr-standard.md`
  - `docs/vault-backed-postgres-bootstrap-job-pattern.md`
- Validated Kustomize render for the four changed app packages.
- Checked that no `gitops/kustomize/*/vault-connection.yaml` still points at `https://vault.yolo.scapegoat.dev`.

### Why

- In-cluster controllers should use Kubernetes service DNS for Vault rather than the public ingress hostname.
- This avoids unnecessary Traefik dependency, avoids extra egress/ingress accounting noise, and prevents secret-bearing Vault headers from entering ingress access logs.

### What worked

- The affected manifests were easy to identify by grepping for `https://vault.yolo.scapegoat.dev` under `gitops/kustomize`.
- Existing packages already used the internal pattern in several namespaces, so the change standardizes the outliers rather than inventing a new pattern.

### What didn't work

- N/A for this edit pass.

### What I learned

- The repo had a mixed VaultConnection pattern: older or shared services mostly used the internal service, while draft-review, hair-booking, keycloak, and smailnail used the public hostname.

### What was tricky to build

- Documentation has to preserve the distinction between public Vault access for humans/operators and internal Vault access for VSO. The correct guidance is not “never use the public Vault hostname”; it is “do not use it for in-cluster VSO sync.”

### What warrants a second pair of eyes

- Confirm that all four applications remain healthy after Argo reconciles the changed VaultConnection resources.
- Confirm VSO status conditions continue to report healthy/ready for the changed namespaces.

### What should be done in the future

- Consider a policy/check that rejects new `VaultConnection` resources under `gitops/kustomize` if they use the public Vault ingress hostname.

### Code review instructions

- Review the four `vault-connection.yaml` files first.
- Then review the docs for the new internal-service guidance.
- Validate live state with:

  ```bash
  kubectl get vaultconnections -A -o json | jq -r '.items[] | [.metadata.namespace,.metadata.name,.spec.address] | @tsv' | sort
  kubectl get vaultstaticsecret -A
  ```

### Technical details

Canonical in-cluster VSO connection:

```yaml
spec:
  address: http://vault.vault.svc.cluster.local:8200
  skipTLSVerify: true
```

# Changelog

## 2026-04-25

- Initial workspace created


## 2026-04-25

Added initial Loki/Promtail GitOps app, Loki Grafana datasource, Hetzner egress and Traefik attribution dashboards, and a Grafana Keycloak access playbook.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/grafana-keycloak-access-playbook.md — Keycloak Grafana access plan
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/loki.yaml — Loki/Promtail application
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/monitoring.yaml — Loki datasource
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/monitoring-extras/grafana-dashboard-hetzner-egress.yaml — Hetzner egress dashboard


## 2026-04-25

Confirmed Grafana was healthy and added a Loki StatefulSet ignoreDifferences rule for defaulted/immutable PVC template fields causing OutOfSync noise.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/loki.yaml — Loki StatefulSet ignoreDifferences configuration
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/04/25/HK3S-0024--add-grafana-dashboards-and-loki-ingress-log-attribution/reference/01-diary.md — Recorded Grafana/Loki rollout debugging


## 2026-04-25

Aligned Traefik Loki selectors with live Promtail labels by switching LogQL and redaction matchers from app_kubernetes_io_name to app=traefik.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/loki.yaml — Promtail redaction selector
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/monitoring-extras/grafana-dashboard-traefik-attribution.yaml — Traefik LogQL selectors


## 2026-04-25

Validated Loki ingestion and Grafana dashboards; repaired Grafana admin password drift so provisioning reloads work and confirmed Loki datasource plus Hetzner/Traefik dashboards are visible.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/04/25/HK3S-0024--add-grafana-dashboards-and-loki-ingress-log-attribution/reference/01-diary.md — Recorded live validation and Grafana provisioning repair


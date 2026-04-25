# Changelog

## 2026-04-25

- Initial workspace created


## 2026-04-25

Created ticket, initial diary, and GitOps manifests for kube-prometheus-stack, Hetzner eth0 egress alerting, Traefik metrics scraping, and Traefik JSON access logs.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/monitoring.yaml — kube-prometheus-stack Argo CD Helm application
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/monitoring-extras/podmonitor-traefik.yaml — Traefik metrics scrape configuration
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/monitoring-extras/prometheus-rule-hetzner-egress.yaml — Hetzner egress alert rules
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/traefik-observability/traefik-helmchartconfig.yaml — Traefik access log and metrics label configuration


## 2026-04-25

Fixed Grafana local-path PVC init ownership repair by adding DAC_OVERRIDE and FOWNER to the Grafana initChownData container capabilities.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/monitoring.yaml — Grafana initChownData security context fix


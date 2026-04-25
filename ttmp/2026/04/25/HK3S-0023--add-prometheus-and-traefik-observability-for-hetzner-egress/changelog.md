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


## 2026-04-25

Hardened Traefik access logs by switching request-header logging from default keep to default drop with a small attribution allowlist after validation showed Vault token headers were being logged.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/traefik-observability/traefik-helmchartconfig.yaml — Traefik access-log header allowlist


## 2026-04-25

Applied monitoring, monitoring-extras, and traefik-observability to the live cluster; validated Argo CD health, running monitoring pods, eth0 node-exporter metrics, Traefik PodMonitor target, Hetzner egress rules, and redacted Traefik JSON access logs.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/monitoring.yaml — Applied monitoring stack
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/monitoring-extras/podmonitor-traefik.yaml — Validated Traefik scrape target
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/traefik-observability/traefik-helmchartconfig.yaml — Validated redacted access log output


## 2026-04-25

Ticket closed


## 2026-04-25

Follow-up: moved VSO VaultConnections for draft-review, hair-booking, keycloak, and smailnail from the public Vault Traefik hostname to the internal Vault service; updated app packaging/runtime docs to document the internal-service rule.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/app-runtime-secrets-and-identity-provisioning-playbook.md — Documents internal VaultConnection guidance for VSO
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/draft-review/vault-connection.yaml — Moved VSO connection to internal Vault service
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/hair-booking/vault-connection.yaml — Moved VSO connection to internal Vault service
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/vault-connection.yaml — Moved VSO connection to internal Vault service
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/smailnail/vault-connection.yaml — Moved VSO connection to internal Vault service


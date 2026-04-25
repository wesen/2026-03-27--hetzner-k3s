# Tasks

## TODO

- [ ] Confirm tailnet DNS zone name (default: tail.scapegoat.dev) and Grafana hostname
- [ ] Design Terraform DNS change in ../terraform for wildcard *.tail.scapegoat.dev pointing at the tailnet ingress Tailscale IP
- [ ] Create tailnet-ingress Kustomize package with namespace, Tailscale auth secret/VSO wiring, Tailscale state persistence, Caddy config, Deployment, and Service
- [ ] Decide and implement TLS path for grafana.tail.scapegoat.dev (DNS-01 wildcard certificate preferred; HTTP over WireGuard acceptable only as temporary MVP)
- [ ] Create Argo CD Application for tailnet-ingress and apply it
- [ ] Bootstrap Tailscale device, capture stable 100.x tailnet IP, and apply Terraform DNS wildcard record
- [ ] Validate grafana.tail.scapegoat.dev from a Tailscale client and verify it is unreachable off-tailnet
- [ ] Document operations, rotation, troubleshooting, and future migration path to Tailscale Kubernetes Operator

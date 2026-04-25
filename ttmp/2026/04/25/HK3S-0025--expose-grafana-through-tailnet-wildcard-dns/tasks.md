# Tasks

## TODO

### Phase 0: confirm naming and DNS model

- [ ] Rename the ticket language from "wildcard DNS" to "dedicated tailnet DNS records" while preserving the existing ticket path.
- [ ] Confirm the private DNS subdomain: `tail.scapegoat.dev`.
- [ ] Confirm the first friendly hostname: `grafana.tail.scapegoat.dev`.
- [ ] Confirm the first operator-managed Tailscale service/device hostname, for example `grafana-k3s-demo-1`.
- [ ] Confirm DNS record type preference in `../terraform`: CNAME to MagicDNS first, A record to `100.x` only if CNAME is not workable.

### Phase 1: research and design the Tailscale Operator path

- [ ] Read the current Tailscale Kubernetes Operator docs for Service exposure, LoadBalancer exposure, Ingress, Gateway API, ProxyClass/ProxyGroup, hostname customization, and auth requirements.
- [ ] Decide the first operator exposure mode for Grafana: annotated Service, Tailscale LoadBalancer Service, IngressClass, or Gateway API.
- [ ] Decide whether the first version uses one operator-managed proxy per service or a shared ProxyGroup.
- [ ] Define the required Tailscale ACL tag, for example `tag:k8s-tailnet-ingress` or `tag:k8s-grafana`.
- [ ] Define how operator OAuth/client credentials will be stored and rendered in Kubernetes, preferably through Vault/VSO.
- [ ] Document the chosen operator resource shape before writing manifests.

### Phase 2: prepare Terraform DNS in ../terraform

- [ ] Inspect `/home/manuel/code/wesen/terraform/dns/zones/scapegoat-dev/envs/prod` and identify the current DigitalOcean record structure.
- [ ] Add Terraform support for explicit tailnet records under `tail.scapegoat.dev`, starting with `grafana.tail.scapegoat.dev`.
- [ ] If using CNAME, point `grafana.tail.scapegoat.dev` at the operator-managed Tailscale MagicDNS name, for example `grafana-k3s-demo-1.<tailnet>.ts.net`.
- [ ] If using A record fallback, make the Tailscale `100.x` value explicit and easy to update.
- [ ] Run `terraform -chdir=dns/zones/scapegoat-dev/envs/prod fmt`.
- [ ] Run `terraform -chdir=dns/zones/scapegoat-dev/envs/prod validate`.
- [ ] Run `terraform -chdir=dns/zones/scapegoat-dev/envs/prod plan` and save/record the expected DNS diff.

### Phase 3: install or configure the Tailscale Kubernetes Operator

- [ ] Create `gitops/applications/tailscale-operator.yaml` or document why the operator is installed outside this repo.
- [ ] Create the operator namespace and credential Secret/VSO resources without committing credentials.
- [ ] Apply the operator Application once and wait for it to become `Synced Healthy`.
- [ ] Validate the operator controller pod is running.
- [ ] Validate the operator can create/manage a test proxy resource or confirm readiness from status conditions.

### Phase 4: expose Grafana through the operator

- [ ] Create a GitOps package for the Grafana tailnet exposure, likely under `gitops/kustomize/tailnet-services/` or `gitops/kustomize/grafana-tailnet/`.
- [ ] Add the operator resource that exposes `monitoring/monitoring-grafana:80` to the tailnet.
- [ ] Set/override the Tailscale hostname to the agreed device name, for example `grafana-k3s-demo-1`.
- [ ] Create an Argo CD Application for the tailnet service exposure and apply it once.
- [ ] Validate the operator-created proxy/device appears in the Tailscale admin console.
- [ ] Capture the MagicDNS name and, if necessary, Tailscale `100.x` IP.

### Phase 5: apply DNS and validate name resolution

- [ ] Apply the Terraform DNS change in `../terraform` after the operator-managed hostname/IP is known.
- [ ] Validate `dig grafana.tail.scapegoat.dev` returns the expected CNAME or A record.
- [ ] Validate resolution from a Tailscale-connected client.
- [ ] Validate that a non-Tailscale client cannot connect even if public DNS resolves the name.

### Phase 6: validate Grafana behavior over tailnet

- [ ] Browse or curl `http://grafana.tail.scapegoat.dev` or `https://grafana.tail.scapegoat.dev`, depending on TLS state.
- [ ] Confirm Grafana login remains enabled; do not enable anonymous access.
- [ ] Check whether Grafana redirects require setting `grafana.grafana.ini.server.root_url` to `https://grafana.tail.scapegoat.dev`.
- [ ] If needed, update `gitops/applications/monitoring.yaml` with the correct `root_url` and revalidate dashboards.
- [ ] Confirm the Hetzner Egress and Traefik Attribution dashboards are reachable through the tailnet URL after login.

### Phase 7: TLS and application identity hardening

- [ ] Decide whether the initial operator endpoint uses Tailscale/MagicDNS HTTPS, custom-domain TLS, or temporary HTTP over WireGuard.
- [ ] If custom-domain HTTPS is required, design DNS-01 certificate issuance for `grafana.tail.scapegoat.dev` or `*.tail.scapegoat.dev`.
- [ ] Add or update the Grafana Keycloak OIDC plan for `grafana.tail.scapegoat.dev` redirect URIs.
- [ ] Move Grafana admin/OIDC secrets to Vault/VSO before enabling broader user access.
- [ ] Validate Tailscale ACLs restrict who can reach the Grafana tailnet device.

### Phase 8: documentation and migration closure

- [ ] Update the implementation guide with exact resources used and actual validation outputs.
- [ ] Update the diary with commands, failures, DNS records, MagicDNS name, Tailscale device name, and screenshots/observations if useful.
- [ ] Add an operations section for rotating Tailscale operator credentials and replacing the Grafana proxy device.
- [ ] Add a future-services pattern for `prometheus.tail.scapegoat.dev`, `alertmanager.tail.scapegoat.dev`, and `argocd.tail.scapegoat.dev` as dedicated DNS records.
- [ ] Close the ticket only after Grafana is reachable via `grafana.tail.scapegoat.dev` from a Tailscale client and all GitOps/DNS state is committed.

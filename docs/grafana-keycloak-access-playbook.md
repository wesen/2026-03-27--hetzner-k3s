---
Title: "Grafana Keycloak Access Plan"
Slug: "grafana-keycloak-access-playbook"
Short: "Plan for exposing Grafana through Traefik with Keycloak OIDC authentication while keeping GitOps and Vault/VSO boundaries clean."
Topics:
- grafana
- keycloak
- oauth
- argocd
- monitoring
- vault
Commands:
- kubectl
- terraform
- vault
Flags: []
IsTopLevel: false
IsTemplate: false
ShowPerDefault: true
SectionType: Playbook
---

# Grafana Keycloak Access Plan

## Current State

Grafana is installed by `gitops/applications/monitoring.yaml` as part of `kube-prometheus-stack` and is intentionally not exposed publicly yet:

```yaml
grafana:
  ingress:
    enabled: false
```

Operators can access it with:

```bash
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```

## Can We Use Keycloak?

Yes. Grafana supports Generic OAuth/OIDC and can authenticate against the existing Keycloak instance. The recommended model is:

```text
browser
  -> https://grafana.yolo.scapegoat.dev
  -> Traefik TLS ingress
  -> Grafana generic_oauth
  -> Keycloak realm/client
```

Do not expose Grafana with anonymous access.

## Required Pieces

1. Keycloak realm/client for Grafana.
2. A client secret stored in Vault.
3. A VSO `VaultStaticSecret` in the `monitoring` namespace that renders the Grafana OAuth secret.
4. Grafana chart values in `gitops/applications/monitoring.yaml` enabling `auth.generic_oauth`.
5. A Grafana ingress with TLS and the `traefik` ingress class.

## Recommended Keycloak Client Shape

Use a confidential OIDC client.

Suggested values:

```text
client_id: grafana
access_type: confidential
standard_flow_enabled: true
valid_redirect_uris:
  - https://grafana.yolo.scapegoat.dev/login/generic_oauth
web_origins:
  - https://grafana.yolo.scapegoat.dev
```

Prefer managing this through the Terraform Keycloak repo, following the existing app realm/client patterns.

## Grafana Configuration Shape

Grafana can read the client secret from an environment variable populated by a Kubernetes Secret:

```yaml
grafana:
  grafana.ini:
    server:
      root_url: https://grafana.yolo.scapegoat.dev
    auth:
      disable_login_form: true
    auth.generic_oauth:
      enabled: true
      name: Keycloak
      allow_sign_up: true
      client_id: grafana
      client_secret: $__env{GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET}
      scopes: openid profile email
      auth_url: https://auth.yolo.scapegoat.dev/realms/<realm>/protocol/openid-connect/auth
      token_url: https://auth.yolo.scapegoat.dev/realms/<realm>/protocol/openid-connect/token
      api_url: https://auth.yolo.scapegoat.dev/realms/<realm>/protocol/openid-connect/userinfo
      role_attribute_path: contains(groups[*], 'grafana-admin') && 'Admin' || 'Viewer'
  envValueFrom:
    GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET:
      secretKeyRef:
        name: grafana-oauth
        key: client-secret
```

The exact realm and group mapping should be chosen before implementation.

## Secret Flow

Recommended Vault path:

```text
kv/infra/monitoring/grafana-oauth
```

Expected rendered Kubernetes Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: grafana-oauth
  namespace: monitoring
stringData:
  client-secret: <from Vault>
```

The `VaultConnection` for monitoring should use the internal Vault service:

```yaml
spec:
  address: http://vault.vault.svc.cluster.local:8200
  skipTLSVerify: true
```

## Implementation Order

1. Create Keycloak client and groups/role mapping.
2. Store client secret in Vault.
3. Add monitoring namespace VSO resources to GitOps.
4. Update `gitops/applications/monitoring.yaml` with `grafana.ini`, `envValueFrom`, and ingress settings.
5. Apply and validate OAuth login.

## Validation

```bash
kubectl -n monitoring get secret grafana-oauth
kubectl -n monitoring rollout status deploy/monitoring-grafana
curl -I https://grafana.yolo.scapegoat.dev/login
```

Then test browser login via Keycloak.

---
Title: "Use a Vault-Backed Keycloak SMTP Reconciler for Realm Email Settings"
Slug: "keycloak-vault-smtp-reconciler-pattern"
Short: "Keep realm SMTP settings aligned with Vault by letting VSO mirror the secret into Kubernetes and a CronJob reconcile Keycloak."
Topics:
- keycloak
- vault
- kubernetes
- argocd
- gitops
- email
- vso
Commands:
- kubectl
- curl
- jq
- git
Flags: []
IsTopLevel: true
IsTemplate: false
ShowPerDefault: true
SectionType: Tutorial
---

## What This Page Covers

This page documents the current platform pattern for SMTP secrets that belong to
Keycloak realms rather than to application pods.

The concrete example is `hair-booking`, but the control-plane split is the main
point:

- Vault is the source of truth for SES SMTP material
- Vault Secrets Operator mirrors a working copy into Kubernetes
- a namespace-local CronJob reconciles the Keycloak realm `smtpServer` block
- Argo CD manages the Kubernetes resources that make this possible
- Vault Kubernetes auth roles and policies are still bootstrapped outside Argo

Use this when an app needs Keycloak to send email, but the SMTP secret should
not live in Git and should not be owned by Terraform state.

## The Problem This Solves

Keycloak stores SMTP configuration inside mutable realm state. Kubernetes and
Argo CD can manage the Keycloak deployment, but they do not natively declare
the internal `smtpServer` block of a realm. Vault can hold the SMTP secret, but
Vault by itself does not update Keycloak.

That means there are two different types of desired state:

- Kubernetes resources such as `ServiceAccount`, `VaultAuth`, `VaultStaticSecret`,
  `ConfigMap`, `CronJob`, and RBAC
- Keycloak realm state that must be updated through the Keycloak admin API

This pattern keeps those responsibilities separate instead of trying to force
all of them into one control loop.

## Current Hair-Booking Flow

The live secret contract is:

```text
Vault kv/apps/hair-booking/prod/ses
  -> VaultStaticSecret keycloak-hair-booking-smtp
    -> Kubernetes Secret keycloak-hair-booking-smtp
      -> CronJob keycloak-hair-booking-smtp-sync
        -> Keycloak admin API
          -> realm hair-booking smtpServer
```

The important resources are:

- Vault policy:
  `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/keycloak-hair-booking-smtp-sync.hcl`
- Vault role:
  `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/keycloak-hair-booking-smtp-sync.json`
- Keycloak Kustomize package:
  `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/`
- App-side contract reference:
  `/home/manuel/code/wesen/hair-booking/docs/keycloak-vault-smtp-sync-playbook.md`

## Secret Shape

The Vault secret remains boring and explicit:

```json
{
  "host": "email-smtp.us-east-1.amazonaws.com",
  "port": "587",
  "username": "<ses access key id>",
  "password": "<ses smtp password>",
  "from_address": "no-reply@mail.scapegoat.dev",
  "from_name": "Hair Booking",
  "reply_to": "no-reply@mail.scapegoat.dev",
  "configuration_set": "mail-scapegoat-dev",
  "starttls": "true",
  "ssl": "false"
}
```

The reconciler converts that into the `smtpServer` shape Keycloak expects.

## What Argo CD Owns

Argo CD owns the Kubernetes-side machinery through the existing Keycloak
application:

- `ServiceAccount` `keycloak-hair-booking-smtp-sync`
- `Role` and `RoleBinding` for the state `ConfigMap`
- `VaultAuth` `keycloak-hair-booking-smtp-sync`
- `VaultStaticSecret` `keycloak-hair-booking-smtp`
- `ConfigMap` `keycloak-hair-booking-smtp-sync`
- `ConfigMap` `keycloak-hair-booking-smtp-sync-state`
- `CronJob` `keycloak-hair-booking-smtp-sync`

The relevant manifest entry point is
`/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak/kustomization.yaml`.

Once the `keycloak` Argo `Application` syncs the revision that contains those
files, Argo becomes the owner of their desired Kubernetes spec.

## What Argo CD Does Not Own

Argo does not currently write Vault auth roles and policies directly.

Those live in Git for review, but the actual write into Vault still happens
through:

```bash
/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-kubernetes-auth.sh
```

That means the current control-plane split is:

- Git + Argo: Kubernetes resources
- Git + bootstrap script: Vault Kubernetes auth policy and role
- CronJob runtime: mutable Keycloak realm `smtpServer`

## Why There Is a State ConfigMap

Keycloak masks the SMTP password in readbacks, so a visible-field comparison is
not enough to prove that the realm is already up to date. The reconciler needs
an idempotence marker that includes the password-derived desired state.

The current solution is:

- compute a hash over the desired SMTP payload and the Vault secret path
- store that hash in `ConfigMap/keycloak-hair-booking-smtp-sync-state`
- compare both:
  - visible `smtpServer` fields from the realm
  - stored desired hash

This is intentionally in Kubernetes state, not in realm custom attributes. That
keeps the idempotence mechanism local to the reconciler and avoids treating
Keycloak metadata as part of the steady-state contract.

## Why This Is a CronJob, Not an Argo Hook

Vault secret changes do not create Git commits, so Argo sync hooks are the
wrong control loop for secret-driven drift.

The CronJob is the correct mechanism because it can react to:

- a fresh Argo sync that changes the reconciler spec
- a secret rotation that VSO mirrors into the namespace
- manual drift inside the Keycloak realm

The current schedule is every 15 minutes.

## Operational Rules

- Put SES SMTP values in Vault at `kv/apps/hair-booking/prod/ses`
- Do not put SMTP passwords in Git or Terraform state
- Do not make application pods read this secret unless the app itself actually
  sends SMTP directly
- Treat `keycloak-bootstrap-admin` as Keycloak admin control-plane input only
- Treat the state `ConfigMap` as reconciler bookkeeping, not as the source of
  truth

## Validation Commands

Render the package:

```bash
kubectl kustomize /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/keycloak >/tmp/keycloak-rendered.yaml
```

Check the mirrored secret and CronJob:

```bash
export KUBECONFIG=/home/manuel/code/wesen/2026-03-27--hetzner-k3s/.cache/kubeconfig-tailnet.yaml
kubectl -n keycloak get vaultauth keycloak-hair-booking-smtp-sync
kubectl -n keycloak get vaultstaticsecret keycloak-hair-booking-smtp
kubectl -n keycloak get cronjob keycloak-hair-booking-smtp-sync
kubectl -n keycloak get configmap keycloak-hair-booking-smtp-sync-state -o yaml
```

Force a one-off run from the CronJob:

```bash
kubectl -n keycloak create job --from=cronjob/keycloak-hair-booking-smtp-sync keycloak-hair-booking-smtp-sync-manual-$(date +%Y%m%d%H%M%S)
```

Read back the realm:

```bash
ADMIN_USER=$(kubectl -n keycloak get secret keycloak-bootstrap-admin -o jsonpath='{.data.username}' | base64 -d)
ADMIN_PASS=$(kubectl -n keycloak get secret keycloak-bootstrap-admin -o jsonpath='{.data.password}' | base64 -d)
TOKEN=$(curl -sS https://auth.yolo.scapegoat.dev/realms/master/protocol/openid-connect/token \
  -H 'content-type: application/x-www-form-urlencoded' \
  --data-urlencode grant_type=password \
  --data-urlencode client_id=admin-cli \
  --data-urlencode username="$ADMIN_USER" \
  --data-urlencode password="$ADMIN_PASS" | jq -r '.access_token')
curl -sS https://auth.yolo.scapegoat.dev/admin/realms/hair-booking \
  -H "authorization: Bearer $TOKEN" | jq '{realm, smtpServer, attributes}'
```

## Hair-Booking Specific Notes

- The app runtime remains separate from the Keycloak SMTP secret.
- The app itself still reads its own runtime secret from
  `kv/apps/hair-booking/prod/runtime`.
- The SMTP secret exists because Keycloak sends login, verification, and
  password-reset email on behalf of `hair-booking`.

That distinction matters. This is not “another app runtime secret.” It is
realm-side Keycloak configuration backed by Vault and reconciled in-cluster.

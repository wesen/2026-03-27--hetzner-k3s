# Changelog

## 2026-03-28

- Initial workspace created
- Added standalone Pretext explorer packaging in the source repo and GitOps manifests in the K3s repo
- Documented the cert-manager issuer-name pitfall: the live cluster uses `letsencrypt-prod`, not `letsencrypt-production`
- Rolled out the app successfully at `https://pretext.yolo.scapegoat.dev` and validated Argo, ingress, and TLS

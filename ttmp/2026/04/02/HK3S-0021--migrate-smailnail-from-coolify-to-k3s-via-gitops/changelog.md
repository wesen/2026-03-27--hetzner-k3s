# Changelog

## 2026-04-02

- Initial workspace created
- Added the main migration design and implementation guide for `smailnail`
- Added an investigation diary documenting the evidence-gathering pass
- Recorded the recommended migration shape: merged `smailnaild` on K3s, shared PostgreSQL, Vault/VSO runtime secrets, GitHub Actions image publishing, and a separate decision about the Dovecot fixture
- Validated the ticket bundle with `docmgr doctor` and confirmed this ticket passed
- Uploaded the final bundle to reMarkable as `HK3S-0021 smailnail K3s migration bundle` under `/ai/2026/04/02/HK3S-0021`
- Added the cross-repo runtime-secrets and identity playbook plus concrete `smailnail` bootstrap assets for Vault runtime secrets, GHCR pull secrets, and Vault Kubernetes auth
- Applied the `smailnail` `k3s-parallel` Keycloak environment against `auth.yolo.scapegoat.dev`, seeded Vault, bootstrapped Vault Kubernetes auth, applied the Argo `Application`, and brought `smailnail` to `Healthy Synced`
- Recorded the live rollout lessons in the stable playbooks: export `AWS_PROFILE` explicitly for backend-backed Terraform applies, use the K3s `keycloak-bootstrap-admin` secret for app-realm bootstrap on the in-cluster Keycloak, and treat missing Vault audiences as a follow-up hardening task rather than a rollout blocker

## 2026-04-02

Wrote the smailnail migration design bundle covering source-repo CI/CD, K3s GitOps packaging, Vault/VSO runtime secrets, shared Postgres, Keycloak alignment, and the optional Dovecot fixture split.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops/design-doc/01-smailnail-k3s-migration-design-and-implementation-guide.md — Primary deliverable
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops/reference/01-smailnail-migration-diary.md — Investigation record

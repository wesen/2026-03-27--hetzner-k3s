# Changelog

## 2026-03-29

- Initial workspace created

## 2026-03-29

Defined the migration scope for Draft Review based on the real Coolify runtime contract, then wrote the K3s migration design guide, execution playbook, and first diary entry before touching any source or cluster state.

## 2026-03-29

Implemented the first migration task in the Draft Review source repo: added GitHub Actions image publishing, GitOps target metadata, and the PR updater script, then validated the repo-local path with Go tests and a full production Docker build.

## 2026-03-29

Created and applied the parallel Keycloak Terraform env for Draft Review against the in-cluster Keycloak instance, producing the `draft-review` realm and `draft-review-web` client for `https://draft-review.yolo.scapegoat.dev`.

## 2026-03-29

Added the Draft Review GitOps package scaffold, Vault runtime secret and private GHCR pull-secret manifests, the Postgres bootstrap job, and the PVC-backed media wiring, then validated that the package renders cleanly and points at a real published GHCR image.

## 2026-03-29

Performed the first live Draft Review rollout, confirmed the app, private GHCR pull, and database bootstrap were healthy, and discovered that the cluster-wide ACME `ClusterIssuer` had drifted out of the cluster entirely. Added a dedicated platform issuer app as the corrective platform fix.

## 2026-03-29

Inspected the hosted Draft Review database and documented the real author-identity migration constraints: the Manuel row is bound to the old hosted issuer and subject UUID, so the K3s migration needs a Terraform-managed `wesen` Keycloak user plus a DB-side issuer/subject rewrite after data import.

## 2026-03-29

Added the Terraform-managed `wesen` user to the K3s Draft Review Keycloak realm, applied it successfully, captured the new subject ID `e0dfdba3-69f8-4b72-8033-d03c958af720`, and stored the generated password in 1Password so the upcoming DB rewrite can target a real, recoverable login identity.

## 2026-03-29

Standardized the ticket-local scripts as `00-...` through `07-...`, then executed the hosted Draft Review data migration end to end: source export, target snapshot, import into cluster Postgres, issuer/subject rewrite for `wesen`, and browser validation that the imported Manuel drafts now show up under the K3s Keycloak identity.

## 2026-03-29

Documented three concrete migration lessons in the ticket and canonical docs:

- PostgreSQL 18 `pg_dump` headers need portability normalization before replay into the cluster restore path
- legacy source schemas can require per-table export normalization, as with `article_sections.body_plaintext`
- large SQL restores are more reliable when copied into the Postgres pod and replayed locally than when streamed over `kubectl exec`

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

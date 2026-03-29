# Changelog

## 2026-03-29

- Initial workspace created

## 2026-03-29

Defined the migration scope for Draft Review based on the real Coolify runtime contract, then wrote the K3s migration design guide, execution playbook, and first diary entry before touching any source or cluster state.

## 2026-03-29

Implemented the first migration task in the Draft Review source repo: added GitHub Actions image publishing, GitOps target metadata, and the PR updater script, then validated the repo-local path with Go tests and a full production Docker build.

## 2026-03-29

Created and applied the parallel Keycloak Terraform env for Draft Review against the in-cluster Keycloak instance, producing the `draft-review` realm and `draft-review-web` client for `https://draft-review.yolo.scapegoat.dev`.

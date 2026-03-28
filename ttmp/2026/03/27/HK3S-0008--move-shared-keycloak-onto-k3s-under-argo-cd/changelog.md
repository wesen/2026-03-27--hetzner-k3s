# Changelog

## 2026-03-27

- Initial workspace created
- Added the deferred implementation outline and task plan so the future Keycloak-on-K3s move is queued explicitly instead of living as verbal follow-up

## 2026-03-28

- Updated the deferred Keycloak-on-K3s plan now that Vault, VSO, the first migrated app, and shared PostgreSQL are all live; marked the platform-prerequisite task complete and recorded that shared PostgreSQL is now the preferred Keycloak backing-store candidate when this ticket is activated
- Added the reusable Vault-backed PostgreSQL bootstrap Job pattern doc, a concrete Keycloak-on-K3s implementation design doc, and a live diary so HK3S-0008 can proceed task by task instead of remaining a vague deferred note

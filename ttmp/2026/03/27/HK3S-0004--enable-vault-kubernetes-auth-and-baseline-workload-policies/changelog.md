# Changelog

## 2026-03-27

- Initial workspace created
- Step 2: Added the repo-managed Vault Kubernetes-auth scaffold, including policy files, role definitions, bootstrap scripts, and the smoke-test Argo CD application (`7904417`)
- Step 3: Applied the smoke namespace/service account through Argo CD and bootstrapped the live Vault auth backend, `kv/` mount, baseline roles, and smoke secrets
- Step 4: Validated service-account login, allowed secret reads, and denied out-of-scope reads against the live K3s Vault
- Step 5: Closed out the ticket docs, resolved doc vocabulary metadata, reran `docmgr doctor`, and prepared the next follow-up tickets

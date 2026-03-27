# Changelog

## 2026-03-27

- Initial workspace created
- Step 2: Added the repo-managed Vault Argo CD scaffold, the non-git AWS KMS secret bootstrap helper, and repo discovery docs (`ec36585`)
- Step 3: Recovered admin access after firewall CIDR drift, bootstrapped the live AWS KMS secret, and deployed Vault through Argo CD
- Step 4: Initialized the K3s Vault, stored recovery material in 1Password, and verified AWS KMS auto-unseal after a forced pod restart
- Step 5: Closed out the ticket, recorded the operator handoff details, and validated the workspace with `docmgr doctor`

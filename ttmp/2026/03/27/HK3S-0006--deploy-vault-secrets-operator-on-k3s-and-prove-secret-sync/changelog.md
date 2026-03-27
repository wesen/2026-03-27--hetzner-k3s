# Changelog

## 2026-03-27

- Initial workspace created
- Step 1: Confirmed the controller-app plus smoke-app packaging model and grounded it in the current repo structure plus official HashiCorp VSO docs
- Step 2: Added the repo-managed VSO scaffold, including the Helm-chart Argo application, local smoke CRs, the `vso-smoke` Vault role/policy, validation script, and implementation diary
- Step 3: Deployed the VSO controller and smoke app live through Argo CD, extended the Vault Kubernetes-auth bootstrap for the smoke role and seed data, and validated secret creation, rotation, and denied-path behavior
- Step 4: Added an intern-facing architecture and implementation guide for VSO, wired it into the ticket, and prepared the bundle for ticket validation and reMarkable publication
- Step 5: Validated the ticket with `docmgr doctor`, uploaded the guide bundle to `/ai/2026/03/27/HK3S-0006` on reMarkable, and verified the uploaded document entry

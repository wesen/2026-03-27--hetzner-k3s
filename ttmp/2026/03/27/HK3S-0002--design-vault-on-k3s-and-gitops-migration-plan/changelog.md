# Changelog

## 2026-03-27

Step 1: created ticket `HK3S-0002`, added the primary design doc, diary, and later the playbook document for the Vault-on-K3s migration research.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/index.md — Ticket overview and current status
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/design-doc/01-vault-on-k3s-and-gitops-migration-design.md — Main architecture and migration design
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/reference/01-investigation-diary.md — Chronological investigation record
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/playbook/01-vault-on-k3s-migration-playbook.md — Ordered implementation sequence

Step 2: mapped the current Coolify Vault deployment, existing Vault policies and seed scripts, CoinVault bootstrap flow, and repo-local operator environment handling to identify which contracts should be preserved and which mechanisms should be retired.

### Related Files

- /home/manuel/code/wesen/terraform/coolify/services/vault/docker-compose.yaml — Current live Vault deployment definition
- /home/manuel/code/wesen/terraform/coolify/services/vault/vault.hcl.awskms.example — Current auto-unseal and Raft configuration baseline
- /home/manuel/code/wesen/terraform/coolify/services/vault/scripts/provision_vault_via_coolify_host.sh — Current Coolify mutation path
- /home/manuel/code/gec/2026-03-16--gec-rag/internal/bootstrap/bootstrap.go — Current CoinVault Vault bootstrap flow
- /home/manuel/code/wesen/terraform/.envrc — Current operator environment pattern

Step 3: inspected the live Hetzner K3s cluster, Argo CD application shape, storage/ingress classes, and node capacity to determine whether Vault can be hosted safely enough on the current single-node environment.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/cloud-init.yaml.tftpl — Current bootstrap boundary for the cluster
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/demo-stack.yaml — Current repo-managed Argo application pattern
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/demo-stack/kustomization.yaml — Current long-term GitOps source path example

Step 4: synthesized the recommended target architecture: Vault in K3s under Argo CD, AWS KMS auto-unseal preserved, Keycloak OIDC kept for human login, Kubernetes auth used for in-cluster workloads, and Vault Secrets Operator used as the default migration bridge for future app secret delivery.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/design-doc/01-vault-on-k3s-and-gitops-migration-design.md — Final design recommendation and phased migration plan
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/playbook/01-vault-on-k3s-migration-playbook.md — Condensed execution sequence

Step 5: validated the ticket with `docmgr doctor`, added missing vocabulary entries, cleaned index file relations, and uploaded the document bundle to reMarkable under `/ai/2026/03/27/HK3S-0002`.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/vocabulary.yaml — Added `vault`, `k3s`, `argocd`, and `migration` topic vocabulary entries
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/index.md — Cleaned index-level related files for a passing doctor run
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/reference/01-investigation-diary.md — Recorded validation and upload evidence

## 2026-03-27

Completed the first full research pass for moving Vault from Coolify to K3s, including current-state analysis, target architecture, phased migration plan, and operator playbook.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/design-doc/01-vault-on-k3s-and-gitops-migration-design.md — Primary deliverable for the migration design
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/playbook/01-vault-on-k3s-migration-playbook.md — Ordered implementation sequence
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0002--design-vault-on-k3s-and-gitops-migration-plan/reference/01-investigation-diary.md — Chronological research record

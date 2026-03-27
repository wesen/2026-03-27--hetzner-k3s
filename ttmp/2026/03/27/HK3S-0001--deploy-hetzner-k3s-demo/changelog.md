# Changelog

## 2026-03-27

- Initial workspace created


## 2026-03-27

Step 1: created deployment ticket, runbook, task list, and diary; identified blocking operator inputs before Terraform apply.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/.gitignore — Excluded IDE-local files from git checkpoints
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/README.md — Source of deployment requirements and operator flow
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/variables.tf — Source of required external inputs and defaults


## 2026-03-27

Step 2: initial repository checkpoint committed; ticket advanced to deployment input collection before terraform.tfvars creation.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/index.md — Current step updated to input collection
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md — Recorded transition to active input-collection step


## 2026-03-27

Step 3: resolved local SSH key and current public IP, identified SSH Git remote and unavailable 1Password session as remaining input blockers.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/index.md — Refined the active blockers and proposed inputs
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/playbook/01-deployment-runbook.md — Documented repo URL and hostname composition constraints
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md — Recorded partial answers and the 1Password CLI failure


## 2026-03-27

Step 4: confirmed public HTTPS repo path, admin CIDR, and final hostname mapping; only ACME email and exact 1Password vault remain unresolved.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/index.md — Reduced blockers to ACME email and token access
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/playbook/01-deployment-runbook.md — Recorded confirmed repo URL and hostname variable mapping
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md — Recorded user-confirmed deployment values


## 2026-03-27

Step 5: created local terraform.tfvars, retrieved the Hetzner token from 1Password, corrected the base domain to scapegoat.dev, and completed terraform init/validate successfully.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/index.md — Promoted Terraform planning to the active step
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md — Recorded local secret creation and Terraform initialization


## 2026-03-27

Step 6: recovered from duplicate SSH key creation by importing the existing key, then hit a Hetzner availability blocker because cpx31 cannot currently be ordered in fsn1.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/index.md — Updated the active blocker and proposed orderable alternatives
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md — Recorded both apply failures and recovery steps


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


## 2026-03-27

Step 7: switched to cpx32 in fsn1, applied successfully, obtained server IP 91.98.46.169, and moved to DNS plus cloud-init monitoring; SSH is not accepting connections yet.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/index.md — Promoted DNS and cloud-init monitoring to the active step
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md — Recorded successful apply and immediate SSH refusal


## 2026-03-27

Step 8: fixed the repo bootstrap defect by adding the missing pq checksum, pushed the public repo, reran bootstrap on the server, and reduced the remaining blocker to DNS propagation for k3s.scapegoat.dev.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/app/go.sum — Added the missing module checksum that broke the on-node Docker build
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md — Recorded the cloud-init root cause


## 2026-03-27

Step 9: added the DigitalOcean DNS records for k3s.scapegoat.dev and *.yolo.scapegoat.dev via the separate Terraform repo; authoritative DNS is correct and the remaining blocker is recursive propagation for ACME.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md — Recorded the external Terraform DNS apply and narrowed the blocker to propagation


## 2026-03-27

Step 10: public DNS propagation completed, cert-manager issued the certificate, and https://k3s.scapegoat.dev returned HTTP/2 200; residual follow-ups are Argo CD drift on postgres and the runtime CoreDNS override.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md — Recorded final HTTPS success and residual risks


## 2026-03-27

Step 11: exposed Argo CD publicly at https://argocd.yolo.scapegoat.dev, issued a certificate for that host, and codified the optional public ingress path in Terraform and cloud-init.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/cloud-init.yaml.tftpl — Added optional Argo CD public ingress bootstrap logic
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/variables.tf — Added the optional `argocd_host` input
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md — Recorded the public Argo CD exposure step


## 2026-03-27

Step 12: ignored the local `.envrc` file so future git checkpoints stay clean, and recorded that the next operational work is Argo CD drift investigation rather than more bootstrap changes.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/.gitignore — Excluded local direnv state from git checkpoints
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md — Recorded the housekeeping step and next operator action


## 2026-03-27

Step 13: moved Argo CD public exposure out of Terraform bootstrap and into GitOps-managed chart resources; `terraform plan` returned `No changes` and the current server was kept.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/charts/demo-stack/templates/argocd-server-config.yaml — GitOps-managed Argo CD config
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/charts/demo-stack/templates/argocd-server-ingress.yaml — GitOps-managed Argo CD ingress
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/cloud-init.yaml.tftpl — Removed the Argo CD hostname bootstrap path
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md — Recorded the Terraform reconciliation step


## 2026-03-27

Step 14: resolved the remaining Argo CD drift by aligning the PostgreSQL StatefulSet template with Kubernetes defaulted fields; `demo-stack` is now `Synced` and `Healthy`.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/charts/demo-stack/templates/postgres-statefulset.yaml — Declared the defaulted StatefulSet fields Argo CD was comparing against
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md — Recorded the drift analysis and resolution


## 2026-03-27

Step 15: removed the temporary CoreDNS public-resolver override, verified in-cluster DNS still works through `/etc/resolv.conf`, and concluded that the earlier issue was likely transient resolver/cache behavior rather than a permanent requirement.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md — Recorded the CoreDNS revert, verification, and rationale


## 2026-03-27

Step 16: moved the live `demo-stack` Argo CD source from Helm templating to Kustomize while keeping the legacy chart only as a bootstrap compatibility path; the live app stayed `Synced` and `Healthy`, and Terraform still reported `No changes`.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/demo-stack/kustomization.yaml — New Kustomize source for the live deployment
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/demo-stack.yaml — Repo-managed Argo CD `Application` manifest for the Kustomize path
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/charts/demo-stack/README.md — Marks the Helm chart as legacy bootstrap compatibility only
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md — Recorded the Kustomize migration and cleanup rationale

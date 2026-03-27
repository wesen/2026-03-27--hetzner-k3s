# Changelog

## 2026-03-27

- Initial workspace created


## 2026-03-27

Step 1: analyzed the MySQL IDE prototype, CoinVault runtime contract, and safe SQL/auth reuse paths; added the design doc, implementation plan, and investigation diary for the Go port and K3s debug deployment.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0010--port-mysql-ide-to-go-and-deploy-a-coinvault-debug-pod/design-doc/01-mysql-ide-port-and-coinvault-debug-deployment-design.md — Primary design recommendation document
- /home/manuel/code/wesen/2026-03-27--mysql-ide/imports/QueryMac.html — Prototype UI analyzed for the port plan
- /home/manuel/code/wesen/2026-03-27--mysql-ide/imports/proxy-server.js — Prototype backend analyzed and rejected for cluster deployment


## 2026-03-27

Step 2: implemented the Go service in the `mysql-ide` repo, deployed it into the CoinVault GitOps package on K3s, extended the CoinVault Keycloak redirect coverage for the debug hostname, and added operator closeout docs for rollout and rollback.

### Related Files

- /home/manuel/code/wesen/2026-03-27--mysql-ide/cmd/mysql-ide/main.go — Go process bootstrap for the service
- /home/manuel/code/wesen/2026-03-27--mysql-ide/internal/httpapi/server.go — HTTP routes, embedded UI serving, and JSON API
- /home/manuel/code/wesen/2026-03-27--mysql-ide/internal/sqlguard/schema.go — Schema metadata inspection and the live aliasing fix
- /home/manuel/code/wesen/2026-03-27--mysql-ide/README.md — App-local runtime and local development documentation
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml — Cluster workload manifest
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-ingress.yaml — Public TLS hostname wiring
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/build-and-import-mysql-ide-image.sh — Single-node K3s image import workflow
- /home/manuel/code/wesen/terraform/keycloak/apps/coinvault/envs/hosted/main.tf — Added redirect support for `coinvault-sql.yolo.scapegoat.dev`
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0010--port-mysql-ide-to-go-and-deploy-a-coinvault-debug-pod/playbook/02-mysql-ide-rollout-and-rollback-playbook.md — Operator closeout playbook

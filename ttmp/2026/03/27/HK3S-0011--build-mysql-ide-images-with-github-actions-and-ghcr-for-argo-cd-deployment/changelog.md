# Changelog

## 2026-03-27

- Initial workspace created

## 2026-03-27

Step 1: analyzed the current mysql-ide image-delivery path, confirmed the app repo is now remote-backed on GitHub, compared GitHub Actions plus GHCR against Argo-built and in-cluster build alternatives, and added the detailed design doc, implementation plan, and investigation diary for the long-term registry-backed rollout path.

### Related Files

- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml — current node-local image contract that the design replaces
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/build-and-import-mysql-ide-image.sh — current manual image-import path
- /home/manuel/code/wesen/2026-03-27--mysql-ide/Dockerfile — existing build input that will become the GitHub Actions source artifact
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0011--build-mysql-ide-images-with-github-actions-and-ghcr-for-argo-cd-deployment/design/01-github-actions-ghcr-image-pipeline-design.md — primary design recommendation

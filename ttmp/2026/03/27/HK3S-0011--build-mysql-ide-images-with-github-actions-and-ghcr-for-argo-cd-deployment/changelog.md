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

## 2026-03-27

Step 2: implemented the GitHub Actions workflow in the `mysql-ide` app repo, published public GHCR images on `main`, upgraded the workflow to current action majors after the first run exposed a Node 20 deprecation warning, switched the live K3s deployment to a pinned GHCR SHA tag, forced an Argo hard refresh to pick up the new Git revision, and verified the registry-backed deployment through health checks plus a real authenticated browser login.

### Related Files

- /home/manuel/code/wesen/2026-03-27--mysql-ide/.github/workflows/publish-image.yaml — new CI workflow that builds and publishes the image to GHCR
- /home/manuel/code/wesen/2026-03-27--mysql-ide/Dockerfile — OCI labels added for package/source metadata
- /home/manuel/code/wesen/2026-03-27--mysql-ide/README.md — updated to document the GHCR-backed release path
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/mysql-ide-deployment.yaml — cut over from node-local image to `ghcr.io/wesen/2026-03-27--mysql-ide:sha-2c3003f`
- /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0011--build-mysql-ide-images-with-github-actions-and-ghcr-for-argo-cd-deployment/reference/02-image-pipeline-implementation-diary.md — detailed rollout diary with run IDs, refresh behavior, and browser verification

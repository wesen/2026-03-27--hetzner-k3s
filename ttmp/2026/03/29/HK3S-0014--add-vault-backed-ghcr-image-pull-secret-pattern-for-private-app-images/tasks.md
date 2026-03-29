# Tasks

## TODO

- [x] Capture the exact current failure mode for private GHCR images in the cluster
- [x] Inventory the local files that will participate in the first implementation target (`coinvault`)
- [x] Write the design guide for Vault-backed GHCR image pull secrets
- [x] Write the implementation playbook for wiring the pattern into K3s
- [x] Define the concrete task list for first implementation in `coinvault`
- [ ] Decide the credential model for GHCR pulls
- [ ] Create or identify the GitHub credential to use for private package pulls
- [ ] Define the Vault path contract for image-pull credentials
- [ ] Decide whether VSO can materialize `kubernetes.io/dockerconfigjson` directly or needs a small transform step
- [ ] Add the first `coinvault` image-pull secret resources in GitOps
- [ ] Attach the pull secret to the `coinvault` `ServiceAccount`
- [ ] Validate a private GHCR-backed `coinvault` rollout without node-local containerd imports
- [ ] Remove the temporary node-cache bridge from the operational story once the pull-secret path is working

## Notes

- First implementation target: `coinvault`
- First affected GitOps files:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/serviceaccount.yaml`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/deployment.yaml`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault/vault-static-secret-runtime.yaml`
- First source-repo package using this path:
  - `/home/manuel/code/gec/2026-03-16--gec-rag`
- This ticket exists because private GHCR package visibility is a separate boundary from GitOps PR automation

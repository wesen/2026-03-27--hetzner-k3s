# Tasks

## TODO

- [ ] Add any follow-up CI/GHCR work if this app starts iterating frequently

## DONE

- [x] Inspect pretext source build and hosting constraints
- [x] Prepare pretext static explorer build and container packaging
- [x] Add K3s GitOps manifests for pretext.yolo.scapegoat.dev
- [x] Push the source-side explorer packaging commits to `wesen/pretext`
- [x] Build and import the explorer image into the live K3s node
- [x] Apply the Argo CD application and wait for the `pretext` app to become healthy
- [x] Validate the public site and update the ticket/changelog for closeout

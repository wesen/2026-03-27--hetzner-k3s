---
Title: smailnail migration diary
Ticket: HK3S-0021
Status: active
Topics:
    - argocd
    - ci-cd
    - ghcr
    - gitops
    - keycloak
    - vault
    - migration
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: ../../../../../../../corporate-headquarters/smailnail/README.md
      Note: Current hosted runtime contract and DB options
    - Path: ../../../../../../../corporate-headquarters/smailnail/docs/deployments/smailnaild-merged-coolify.md
      Note: |-
        Current merged deployment target and env contract
        Current merged deployment shape reviewed during investigation
    - Path: ../../../../../../../hair-booking/.github/workflows/publish-image.yaml
      Note: Release automation reference pattern
    - Path: ../../../../../../../terraform/keycloak/apps/smailnail/envs/hosted/main.tf
      Note: Current hosted Keycloak env reviewed during investigation
    - Path: docs/source-app-deployment-infrastructure-playbook.md
      Note: Canonical K3s source-to-GitOps release model
    - Path: docs/vault-backed-postgres-bootstrap-job-pattern.md
      Note: Shared Postgres bootstrap pattern evaluated for smailnail
    - Path: gitops/kustomize/draft-review/deployment.yaml
      Note: GitOps deployment reference for OIDC app wiring
ExternalSources: []
Summary: Chronological investigation log for the smailnail Coolify-to-K3s migration planning pass.
LastUpdated: 2026-04-02T09:05:48.258591808-04:00
WhatFor: Use this diary to understand how the migration design was derived, what evidence shaped it, and where the remaining implementation work sits.
WhenToUse: Read this when reviewing the design doc or continuing the migration work later.
---


# smailnail migration diary

## Goal

Capture the investigation that produced the migration design for moving `smailnail` from its current Coolify shape to the K3s GitOps platform.

## Step 1: Map the existing system and write the migration guide

The first task was to treat `smailnail` as a platform migration problem instead of a single-manifest problem. I needed to understand the source repo runtime, the current hosted shape, the central Keycloak ownership, and the established K3s app patterns in this infra repo before writing any recommendations.

The most important conclusion from this step was that the migration target is already latent in the codebase. The merged `smailnaild` server is the product to migrate. The missing work is mostly control-plane glue: image publishing, GitOps PR creation, Vault/VSO secret delivery, Argo packaging, and Keycloak hostname alignment.

### Prompt Context

**User prompt (verbatim):** "Now, let's tackle the last move from coolify to k3s (argocd, cicd pipeline, keycloak, etc...), which would be the smailnail deploy (see /home/manuel/code/wesen/corporate-headquarters/smailnail)

Create a new ticket and reate a detailed analysis / design / implementation guide that is very detailed for a new intern, explaining all the parts of the system needed to understand what it is, with prose paragraphs and bullet point sand pseudocode and diagrams and api references and file
  references.
  It should be very clear and detailed. Store in the ticket and the nupload to remarkable.

You can look at other apps we moved like ~/code/wesen/hair-booking for example"

**Assistant interpretation:** Create a new HK3S ticket in this repo, investigate the current `smailnail` deployment and related platform repos, write a detailed intern-facing migration guide plus diary, store them in the ticket workspace, validate the docs, and upload the bundle to reMarkable.

**Inferred user intent:** Finish the remaining architectural planning for the last Coolify-hosted application by producing a handoff-quality document that another engineer can implement from with minimal rediscovery.

**Commit (code):** N/A

### What I did
- Created ticket `HK3S-0021` with a design doc and diary under `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops`.
- Read the `smailnail` source repo README, Dockerfile, entrypoint, hosted deployment docs, local docker-compose stack, OIDC implementation, and database bootstrap code.
- Compared the current source repo against `hair-booking` to identify the missing source-repo release artifacts.
- Compared the desired K3s app shape against `draft-review` and the platform playbooks in this repo.
- Read the central Terraform `smailnail` Keycloak env to understand what already exists and what appears stale.

### Why
- The user asked for a very detailed implementation guide, and that only works if the document is evidence-backed.
- `smailnail` spans multiple control planes: the source repo, the central Keycloak Terraform repo, and this GitOps repo. Any design that ignored one of those would be incomplete.
- Prior migrations such as `draft-review` and `hair-booking` already solved parts of this problem. Reusing them is better than inventing a new pattern.

### What worked
- The source repo already exposed most of the runtime contract clearly through `README.md`, `Dockerfile`, and `docker-entrypoint.smailnaild.sh`.
- The K3s repo already had high-quality reference patterns for:
  - source-repo release automation
  - runtime secret delivery via Vault/VSO
  - Argo application bootstrapping
  - shared-Postgres bootstrap jobs
- The central Terraform repo already contained a hosted `smailnail` realm and both browser and MCP clients, which reduced ambiguity around client IDs and realm ownership.

### What didn't work
- Searching for `publish-image.yaml`, `deploy/gitops-targets.json`, and `open_gitops_pr.py` in the `smailnail` repo returned no results. That was not a transient failure; it was evidence that the standardized source-repo release path has not been implemented there yet.
- One `rg` search against the broader `terraform` and `corporate-headquarters` trees returned far more matches than were useful for the immediate task, so I narrowed the investigation to the exact Keycloak env and deployment docs instead of continuing to mine the broad search output.

### What I learned
- `smailnaild` is already a merged production server serving SPA, API, browser OIDC, and MCP from one binary. That should be the K3s target.
- The app is not locked to SQLite. It can already run against Postgres, which makes the K3s design cleaner.
- The hosted Keycloak Terraform looks partially stale relative to the newer merged-host docs. The browser client still points at `smailnail.mcp.scapegoat.dev`, while the newer docs point at `smailnail.scapegoat.dev`.
- The hosted Dovecot fixture is operationally separate from the app. It uses raw TCP ports and should not be smuggled into the main app migration as though it were another HTTP ingress.

### What was tricky to build
- The hardest part was not understanding the app code. It was separating the primary migration scope from adjacent infrastructure. `smailnail` has a main hosted app, a legacy standalone MCP deployment, a Dovecot fixture, and Keycloak Terraform state. If I had treated all of that as one flat system, the resulting guide would have been vague and harder to execute.
- Another subtle point was avoiding stale documentation traps. The hosted Terraform browser-client host and the newer merged deployment docs do not line up cleanly. That kind of mismatch is exactly the sort of thing that can send an intern down the wrong path if it is not called out explicitly.

### What warrants a second pair of eyes
- The final desired hostname for the K3s app. I inferred `smailnail.yolo.scapegoat.dev` from the platform pattern, but that should still be confirmed.
- The GHCR package visibility decision. Whether the package is public or private determines whether a pull-secret slice is mandatory on day one.
- The old hosted browser-client redirect/origin values in Terraform. Those should be verified against intended reality before anyone copies them forward.
- Whether the Dovecot fixture is part of the same migration project or a separate cleanup item.

### What should be done in the future
- Implement the source-repo release path in `smailnail`.
- Add the K3s GitOps package and Argo application in this repo.
- Add or update the `smailnail` Keycloak env in the Terraform repo for the K3s hostname.
- Decide explicitly what to do about the Dovecot fixture.

### Code review instructions
- Start with the main design doc:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops/design-doc/01-smailnail-k3s-migration-design-and-implementation-guide.md`
- Then compare the cited reference files:
  - `/home/manuel/code/wesen/corporate-headquarters/smailnail/README.md`
  - `/home/manuel/code/wesen/corporate-headquarters/smailnail/docs/deployments/smailnaild-merged-coolify.md`
  - `/home/manuel/code/wesen/hair-booking/.github/workflows/publish-image.yaml`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/draft-review/deployment.yaml`
- Validate that the design’s conclusions match those files directly.

### Technical details
- Ticket creation commands:
  - `docmgr ticket create-ticket --ticket HK3S-0021 --title "Migrate smailnail from Coolify to K3s via GitOps" --topics argocd,ci-cd,ghcr,gitops,keycloak,vault,migration`
  - `docmgr doc add --ticket HK3S-0021 --doc-type design-doc --title "smailnail K3s migration design and implementation guide"`
  - `docmgr doc add --ticket HK3S-0021 --doc-type reference --title "smailnail migration diary"`
- Key source files inspected:
  - `/home/manuel/code/wesen/corporate-headquarters/smailnail/README.md`
  - `/home/manuel/code/wesen/corporate-headquarters/smailnail/Dockerfile`
  - `/home/manuel/code/wesen/corporate-headquarters/smailnail/scripts/docker-entrypoint.smailnaild.sh`
  - `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/http.go`
  - `/home/manuel/code/wesen/corporate-headquarters/smailnail/pkg/smailnaild/db.go`
  - `/home/manuel/code/wesen/terraform/keycloak/apps/smailnail/envs/hosted/main.tf`
  - `/home/manuel/code/wesen/hair-booking/.github/workflows/publish-image.yaml`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/draft-review/deployment.yaml`

## Related

- Design doc: [01-smailnail-k3s-migration-design-and-implementation-guide.md](../design-doc/01-smailnail-k3s-migration-design-and-implementation-guide.md)
- Ticket index: [index.md](../index.md)
- Tasks: [tasks.md](../tasks.md)

## Step 2: Validate the ticket and deliver the bundle to reMarkable

After the design bundle was written, the remaining task was delivery discipline rather than more analysis. I needed to confirm that the ticket structure was valid, verify that the documents were discoverable through `docmgr`, and upload a stable bundle to reMarkable so the handoff existed outside the local checkout.

The key result from this step was that the `HK3S-0021` ticket itself passed validation, the bundle upload succeeded, and the uploaded document can now be found on reMarkable under the dated ticket folder. The only validation warning in the wider tree belonged to an unrelated ticket from `2026-04-01`.

### What I did
- Listed the docs for `HK3S-0021` with `docmgr doc list --ticket HK3S-0021`.
- Verified reMarkable tooling and cloud auth with `remarquee status` and `remarquee cloud account --non-interactive`.
- Ran a dry-run bundle upload for the ticket index, design doc, diary, task list, and changelog.
- Uploaded the final bundle to `/ai/2026/04/02/HK3S-0021`.
- Verified the remote listing with `remarquee cloud ls /ai/2026/04/02/HK3S-0021 --long --non-interactive`.
- Re-ran `docmgr doctor --ticket HK3S-0021 --stale-after 30` to capture the final validation state.

### Why
- The user asked not only for a ticket bundle, but also for reMarkable delivery.
- A design handoff is incomplete if the ticket cannot be validated and found later.
- A dry-run before upload reduces the chance of packaging the wrong files or ordering the bundle poorly.

### What worked
- The ticket docs were registered correctly in `docmgr`.
- The dry-run matched the intended file order and remote path.
- The real upload succeeded on the first attempt.
- Remote verification showed the expected bundle name in the ticket folder.
- `docmgr doctor` reported `HK3S-0021` as passing all checks.

### What didn't work
- `docmgr doctor` still reported a missing `index.md` under `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/04/01/HK3S-0021--reconcile-hair-booking-keycloak-smtp-from-vault-on-k3s`, but that finding was unrelated to the new smailnail ticket.

### What I learned
- The ticket bundle is better delivered as one reMarkable PDF bundle than as separate uploads because it preserves reading order and gives a single handoff artifact.
- Validation output from `docmgr doctor --ticket HK3S-0021` can still mention unrelated sibling tickets, so the per-ticket subsection matters more than the top-level finding count.

### Technical details
- Delivery commands:
  - `docmgr doc list --ticket HK3S-0021`
  - `remarquee status`
  - `remarquee cloud account --non-interactive`
  - `remarquee upload bundle --dry-run --non-interactive --toc-depth 2 --name "HK3S-0021 smailnail K3s migration bundle" --remote-dir "/ai/2026/04/02/HK3S-0021" ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops/index.md ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops/design-doc/01-smailnail-k3s-migration-design-and-implementation-guide.md ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops/reference/01-smailnail-migration-diary.md ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops/tasks.md ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops/changelog.md`
  - `remarquee upload bundle --non-interactive --toc-depth 2 --name "HK3S-0021 smailnail K3s migration bundle" --remote-dir "/ai/2026/04/02/HK3S-0021" ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops/index.md ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops/design-doc/01-smailnail-k3s-migration-design-and-implementation-guide.md ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops/reference/01-smailnail-migration-diary.md ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops/tasks.md ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops/changelog.md`
  - `remarquee cloud ls /ai/2026/04/02/HK3S-0021 --long --non-interactive`
  - `docmgr doctor --ticket HK3S-0021 --stale-after 30`

### Review instructions
- Confirm the uploaded artifact exists remotely:
  - `/ai/2026/04/02/HK3S-0021`
- Confirm the local ticket bundle still contains the expected source docs:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops/index.md`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops/design-doc/01-smailnail-k3s-migration-design-and-implementation-guide.md`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/04/02/HK3S-0021--migrate-smailnail-from-coolify-to-k3s-via-gitops/reference/01-smailnail-migration-diary.md`

## Step 3: Execute the real K3s rollout and update the stable operator playbooks with the failures we actually hit

The design phase was finished, the source-repo CI path was finished, and the live GitOps PR path was finished. At that point the only honest next move was to do the operator work for real instead of leaving the ticket in “prepared but unproven” state. That meant creating the `smailnail` `k3s-parallel` Keycloak env in the central Terraform repo, seeding Vault paths for runtime and image pull, adding the missing Vault Kubernetes auth role and policy files, and then letting Argo reconcile the application.

The key result from this step was that `smailnail` is now actually running on K3s. The live checks all lined up:

- Argo: `Healthy Synced`
- Pod: `Ready`
- DB bootstrap Job: `Complete`
- Ingress: present on `smailnail.yolo.scapegoat.dev`
- `/readyz`: `HTTP/2 200`
- OIDC discovery: issuer `https://auth.yolo.scapegoat.dev/realms/smailnail`

### What I did

- Added the stable cross-repo playbook:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/docs/app-runtime-secrets-and-identity-provisioning-playbook.md`
- Added `smailnail` Vault bootstrap assets:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-smailnail-runtime-secrets.sh`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-smailnail-image-pull-secret.sh`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/smailnail.hcl`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/policies/kubernetes/smailnail-db-bootstrap.hcl`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/smailnail.json`
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/vault/roles/kubernetes/smailnail-db-bootstrap.json`
- Added the Terraform env:
  - `/home/manuel/code/wesen/terraform/keycloak/apps/smailnail/envs/k3s-parallel/`
- Read the Keycloak bootstrap admin credentials from:
  - `kubectl -n keycloak get secret keycloak-bootstrap-admin`
- Applied the Terraform env against:
  - `https://auth.yolo.scapegoat.dev`
- Seeded Vault:
  - `kv/apps/smailnail/prod/runtime`
  - `kv/apps/smailnail/prod/image-pull`
- Re-ran:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/bootstrap-vault-kubernetes-auth.sh`
- Applied and refreshed:
  - `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/smailnail.yaml`
- Validated:
  - `kubectl -n argocd get application smailnail`
  - `kubectl -n smailnail get pods,jobs,ingress,secrets`
  - `curl -I https://smailnail.yolo.scapegoat.dev/readyz`
  - `curl https://auth.yolo.scapegoat.dev/realms/smailnail/.well-known/openid-configuration`

### What worked

- The merged GitOps PR was enough once the cluster-side prerequisites were truly present.
- The new runtime and image-pull Vault secrets synced into Kubernetes immediately through VSO.
- The DB bootstrap job completed successfully on the first run.
- The deployment pulled the private GHCR image successfully and became ready.
- Argo finished with the expected final state:
  - `Healthy Synced Succeeded successfully synced (all tasks run)`

### What didn't work

- The first real Terraform apply failed because the new env had only been initialized locally with `-backend=false` before the live run.
- The next Terraform attempt still failed until I exported `AWS_PROFILE=manuel` in the exact shell running Terraform. The AWS CLI worked already, which made this a shell-environment mismatch rather than a platform outage.
- I briefly prepared a local rename from Vault role `smailnail` to `smailnail-prod`, then checked `origin/main` and confirmed that the merged Argo contract still used `smailnail`. That rename would have created a false local/remote mismatch during rollout.
- Vault printed warnings that many existing Kubernetes auth roles do not have an `audience` configured. Those warnings did not block rollout, but they are real follow-up hardening work.

### What I learned

- The Terraform backend contract needs to be documented separately from the Keycloak provider contract. Keycloak credentials can be correct while the apply still fails on S3 backend access.
- The in-cluster Keycloak bootstrap secret is the cleanest first-operator path for new app-realm creation on `auth.yolo.scapegoat.dev`.
- The stable playbooks needed to say two things more explicitly:
  - export `AWS_PROFILE` before backend-backed Terraform applies
  - check `origin/main` before changing Vault role names locally

### Technical details

- K3s doc/provisioning commit:
  - `7685e64 feat(smailnail): add k3s provisioning playbook and bootstrap assets`
- Terraform env commit:
  - `afc4a76 feat(smailnail): add k3s parallel keycloak env`
- Live readiness result:
  - `curl -I https://smailnail.yolo.scapegoat.dev/readyz`
  - `HTTP/2 200`
- Live OIDC issuer result:
  - `https://auth.yolo.scapegoat.dev/realms/smailnail`

## Step 4: Run the post-deploy anonymous validation pass

After the rollout was healthy at the infrastructure level, I still wanted one more layer of proof from the public surface before declaring the deployment usable. I did not have a real end-user login session to exercise browser-authenticated flows, so the right next step was to validate the anonymous edges that should already behave deterministically:

- homepage renders
- login link redirects to the correct Keycloak realm
- `/api/me` returns an unauthenticated result rather than a crash or routing error
- `/mcp` advertises the correct protected-resource metadata

The key result from this step was that all of those pre-login surfaces behave consistently with the intended design. That means the remaining unproven slice is actual authenticated application behavior, not ingress, Keycloak wiring, or MCP metadata.

### What I did

- Fetched the homepage:
  - `curl -D - https://smailnail.yolo.scapegoat.dev/`
- Fetched the anonymous API edge:
  - `curl -D - https://smailnail.yolo.scapegoat.dev/api/me`
- Fetched the MCP endpoint and protected-resource metadata:
  - `curl -D - https://smailnail.yolo.scapegoat.dev/mcp`
  - `curl https://smailnail.yolo.scapegoat.dev/.well-known/oauth-protected-resource`
- Used Playwright to load the homepage and click the login link once.

### What worked

- Homepage returned `200` and rendered the signed-out UI.
- The sign-in link redirected to:
  - `https://auth.yolo.scapegoat.dev/realms/smailnail/protocol/openid-connect/auth?...`
- `/api/me` returned `401`, which is the correct anonymous response.
- `/mcp` returned a Bearer challenge with:
  - `resource_metadata="https://smailnail.yolo.scapegoat.dev/.well-known/oauth-protected-resource"`
- The protected-resource document advertised:
  - authorization server `https://auth.yolo.scapegoat.dev/realms/smailnail`
  - resource `https://smailnail.yolo.scapegoat.dev/mcp`

### What didn't work

- The signed-out homepage logs a browser-console `401` for `/api/me`, but that is just the anonymous session probe and not a deployment error.
- I did not complete a real user login, so `GET /api/me` after auth, UI account creation, and authenticated MCP calls remain unverified.

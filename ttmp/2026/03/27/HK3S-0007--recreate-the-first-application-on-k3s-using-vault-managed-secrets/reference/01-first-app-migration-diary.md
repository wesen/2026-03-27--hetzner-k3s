---
Title: First app migration diary
Ticket: HK3S-0007
Status: active
Topics:
    - vault
    - k3s
    - migration
    - gitops
    - applications
DocType: reference
Intent: long-term
Owners: []
RelatedFiles: []
ExternalSources: []
Summary: Chronological diary for choosing and implementing the first real application migration onto K3s using Vault-managed secrets.
LastUpdated: 2026-03-27T16:56:00-04:00
WhatFor: Use this to review the exact decisions, commands, and reasoning behind the first real application migration after the Vault platform work.
WhenToUse: Read this when continuing or reviewing HK3S-0007.
---

# First app migration diary

## Goal

Choose the first real application to deploy on K3s using the new Vault plus VSO platform path, then document and execute that migration with enough detail that the next app migration is easier.

## Step 1: Compare candidates and choose the first app based on deployability, not just secret simplicity

I started HK3S-0007 by revisiting the candidate list from the earlier platform design. The original tension was straightforward: hair-booking had the simpler secret story, while CoinVault had the richer existing hosted runtime contract. At the platform-design stage that was still an open question. For actual implementation, I needed to answer a stricter question: which app can be recreated as a real K3s workload now, not just theoretically later.

I re-read the current HK3S-0007 ticket, the earlier migration design ticket, the hair-booking Vault SES handoff, and the current CoinVault deployment contract. That comparison changed the framing. Hair-booking does have a narrow Vault policy and a very simple secret path at `kv/apps/hair-booking/prod/ses`, but the repository itself is not yet a real hosted service contract. It has no meaningful K8s packaging, no actual runtime deployment documentation, and no obvious backend container entrypoint to move. It is a simpler secret integration, but not a simpler application migration.

CoinVault is the opposite. It has more moving parts, but it is a real deployable service today:

- a Dockerfile
- a hosted runtime contract
- a health check
- a public route surface
- an existing Keycloak OIDC integration
- an existing Vault-backed runtime contract
- a known MySQL dependency and local SQLite persistence paths

That made the decision much clearer. For the first K3s migration ticket, the right criterion is "smallest realistic end-to-end hosted workload," not "smallest isolated secret."

### What I did
- Read the HK3S-0007 index, plan, and tasks.
- Re-read the earlier platform design and migration guidance from HK3S-0002.
- Read the hair-booking SES/Vault handoff document and current least-privilege policy.
- Read the CoinVault Coolify deployment contract, hosted operations playbook, Dockerfile, runtime bootstrap code, and entrypoint.
- Confirmed the live K3s cluster already has the platform layers this app needs:
  - Vault
  - Vault Kubernetes auth
  - Vault Secrets Operator

### Why
- The first migration needs to end in a live workload. A simpler secret contract is not enough if the app itself is not ready to host.

### What worked
- The comparison produced a decisive answer instead of another round of ambiguous “maybe later” analysis.
- CoinVault’s existing docs are strong enough that I can translate them into K3s primitives rather than inventing a deployment from scratch.

### What didn't work
- I initially expected hair-booking to remain the favorite because of its smaller Vault surface. Once I looked at the repo shape, that assumption did not hold up.
- My first `docmgr doc add` attempt used `--type` instead of `--doc-type`, which failed with `unknown flag: --type`.

### What I learned
- The right first migration target is the simplest *deployable* app, not the simplest *secret path*.
- CoinVault can likely run on K3s without its old AppRole bootstrap path if VSO provides the runtime env values and the Pinocchio YAML as Kubernetes-native inputs.

### What was tricky to build
- The trickiest part was not the tech; it was being honest about the decision criteria. Hair-booking is the cleaner secret example, but not the cleaner first hosted migration.

### What warrants a second pair of eyes
- Review the decision criteria before the live deploy work goes further: if someone strongly prefers a purely lower-risk secret demo, that should be a separate ticket, not this “first real application” ticket.

### What should be done in the future
- Write the runtime contract for CoinVault on K3s, then scaffold the Argo app, VSO resources, and deployment manifests.

## Step 2: Translate the CoinVault hosted contract into K3s primitives and helper scripts

After locking the app choice, I mapped the existing CoinVault runtime contract into K3s objects instead of copying the old Coolify bootstrap literally. The key insight from the app repo was that CoinVault does not actually require AppRole when running inside Kubernetes. The old bootstrap binary existed to fetch secret material into a container running outside the cluster. On K3s, VSO can provide those values as Kubernetes-native inputs instead.

That led to the concrete K3s shape:

- an Argo CD application named `coinvault`
- a local Kustomize package under `gitops/kustomize/coinvault`
- namespace `coinvault`
- service account `coinvault`
- one PVC for the timeline and turns SQLite files
- one `VaultConnection`
- one `VaultAuth`
- two `VaultStaticSecret` resources:
  - `coinvault-runtime`
  - `coinvault-pinocchio`
- one deployment, service, and ingress

I also added three helper scripts because this ticket needs more than manifests. It needs operator procedures:

- [`seed-coinvault-k3s-vault-secrets.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/seed-coinvault-k3s-vault-secrets.sh)
  - copies the current CoinVault runtime and Pinocchio secrets from the old Vault into the K3s Vault and overrides the public URL for the K3s hostname
- [`build-and-import-coinvault-image.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/build-and-import-coinvault-image.sh)
  - builds the app image from the private CoinVault repo and imports it directly into the single K3s node’s containerd image store
- [`validate-coinvault-k3s.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-coinvault-k3s.sh)
  - checks the Argo app, deployment, VSO destination secrets, health endpoint, and login redirect

The image-import script is intentionally documented as a bootstrap exception, not the desired long-term model. The real long-term answer is a registry-backed image publish path. But for a single-node cluster and a private repo with no package scope ready, direct import is the most pragmatic way to land the first live migration without adding another platform ticket first.

### What I did
- Added [coinvault.yaml](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/applications/coinvault.yaml).
- Added the full Kustomize package under [/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/gitops/kustomize/coinvault).
- Chose the runtime shape:
  - VSO-backed env secret for runtime values
  - VSO-backed mounted secret for Pinocchio YAML
  - static K3s hostname and OIDC issuer/client ID values in the deployment manifest
- Added the Vault-seed, image-import, and validation scripts.
- Updated the ticket tasks and changelog to reflect that the repo-managed scaffold now exists.

### Why
- The first migrated app should use the new K3s platform path, not drag the off-cluster AppRole pattern into the cluster unnecessarily.
- A single scaffold pass keeps the runtime contract coherent and easier to review.

### What worked
- The existing CoinVault entrypoint is already flexible enough to run without bootstrap mode as long as the needed env vars and profile files are present.
- The earlier planning work had already committed the `coinvault-prod` Vault policy and Kubernetes role, which reduced the new Vault-side work.

### What didn't work
- Nothing failed structurally in this step. The main complexity was choosing which values should stay static in the deployment and which should remain Vault-backed.

### What I learned
- CoinVault is a strong first migration target because the old hosted contract is explicit enough to translate directly into K8s resources.
- The biggest real blocker is image distribution, not secret delivery.

### What was tricky to build
- The trickiest part was deciding not to overfit the old bootstrap path. Inside K3s, VSO is the better primitive.

### What warrants a second pair of eyes
- Review the image-import exception carefully. It is pragmatic, but it should stay clearly documented as temporary.

### What should be done in the future
- Validate the scaffold locally, then perform the live rollout: seed secrets, adjust Keycloak redirect URIs, import the image, apply the Argo app, and validate the public runtime.

## Step 3: Seed the K3s Vault with CoinVault runtime values that point at cluster MySQL

Once shared MySQL existed, the first real migration step was not “deploy the app.” It was “make sure the app secret contract now points at the right database.” The old CoinVault runtime secret in Vault still carried the Coolify-only MySQL hostname. If I had deployed the app unchanged, I would just have recreated the old networking failure inside K3s.

I therefore changed the K3s-side helper script to preserve the existing hosted OIDC/session material while allowing explicit overrides for:

- MySQL host
- MySQL port
- database
- read-only user
- read-only password

Then I used the old Vault as the source for:

- `session_secret`
- `oidc_client_secret`
- `oidc_issuer_url`
- `oidc_client_id`
- Pinocchio payloads

and the new K3s `mysql-auth` secret as the source for:

- `mysql.mysql.svc.cluster.local`
- port `3306`
- database `gec`
- user `coinvault_ro`
- the current cluster MySQL password

That produced a K3s Vault runtime secret that still matched the hosted runtime contract, but now targeted the cluster-local MySQL service instead of the Coolify-internal hostname.

I also rechecked the pending Terraform Keycloak change at [`main.tf`](/home/manuel/code/wesen/terraform/keycloak/apps/coinvault/envs/hosted/main.tf). Terraform plan showed `No changes`, which means the live Keycloak configuration already accepted the `coinvault.yolo.scapegoat.dev` callback/origin. So I committed that Terraform repo change purely to reconcile Git with the already-live state.

### What I did
- Added explicit MySQL override support to [`seed-coinvault-k3s-vault-secrets.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/seed-coinvault-k3s-vault-secrets.sh).
- Seeded `kv/apps/coinvault/prod/runtime` in K3s Vault from the old Vault plus the new cluster MySQL credentials.
- Confirmed the resulting K3s secret now points at `mysql.mysql.svc.cluster.local`.
- Confirmed the Keycloak callback/origin path for `coinvault.yolo.scapegoat.dev` was already live and committed the Terraform repo.

### Why
- This preserves the existing runtime contract while swapping only the infrastructure dependency that changed.

### What worked
- The old and new sources fit together cleanly: old Vault for OIDC/session values, K3s MySQL for database values.
- DNS for `coinvault.yolo.scapegoat.dev` was already covered by the existing wildcard `*.yolo.scapegoat.dev`.

### What didn't work
- The break-glass read path for the old Vault init bundle did not work via the local GPG agent state, so I had to switch to a deterministic `op` plus temporary `GNUPGHOME` flow.

### What I learned
- For migration tickets, separating “identity/auth secret continuity” from “infrastructure endpoint cutover” makes the rollout much easier to reason about.

### What should be done in the future
- Build the image reproducibly, import it to the K3s node, and let Argo reconcile the workload.

## Step 4: Make the CoinVault image build reproducible from this workstation and import it to the node

The next blocker was not in Kubernetes. It was in the application repo’s build assumptions.

The first `docker build` failed because the CoinVault repo still contained local `replace` directives in `go.mod` that point to workstation-specific paths:

- `/home/manuel/code/wesen/corporate-headquarters/geppetto`
- `/home/manuel/code/wesen/corporate-headquarters/pinocchio`

Those paths do not exist inside the Docker build context, so the build could not even resolve dependencies. I fixed the image-import helper script rather than mutating the app repo itself. The script now:

- creates a temporary build context
- copies the repo into it
- drops the local `replace` directives
- runs `go mod tidy`
- builds the image from that temporary context

That exposed the second issue: once the `replace` directives were removed, the checked-in `go.sum` was not complete enough for the Docker build. Running `go mod tidy` in the temporary build context solved that too without changing the app repo.

After those two script fixes, the image built successfully and imported into the K3s node as:

- `coinvault:hk3s-0007`

### What I did
- Updated [`build-and-import-coinvault-image.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/build-and-import-coinvault-image.sh) to use a temporary build context.
- Removed the local `replace` directives inside that temp context only.
- Added `go mod tidy` inside the temp context.
- Built and imported `coinvault:hk3s-0007` into the node’s containerd store.

### Why
- The first app migration needs a reproducible operator path from this repo, not a build that only works on one workstation layout.

### What worked
- The final image imported cleanly and was visible in `k3s ctr images ls`.

### What didn't work
- The first build failed on missing local `replace` paths.
- The second build failed on incomplete `go.sum` metadata once those replacements were removed.

### What I learned
- A single-node import exception is acceptable for the first app migration, but the import script still has to be workstation-independent or it is not a real operator path.

### What should be done in the future
- Apply the Argo application and let the cluster attempt the first real rollout.

## Step 5: Resolve the Argo deadlock and bring the application to `Synced Healthy`

Once the image was on the node, I created the Argo `Application` for CoinVault. The Vault/VSO resources reconciled immediately. The app itself did not.

The first cluster-side problem was not a bad image or a bad deployment spec. It was an Argo sync-order deadlock caused by the storage class behavior:

- the PVC `coinvault-data` used `local-path`
- it waited for the first pod consumer before binding
- Argo had the PVC in an earlier sync wave than the Deployment
- Argo then waited for the PVC to become healthy before it would apply the Deployment

That is a classic `WaitForFirstConsumer` deadlock. I fixed it by moving the PVC into the same sync wave as the Deployment.

There was one more Argo nuance after that. The application still held onto the stale older sync operation, so even though the desired revision had changed, the controller was still executing the earlier operation state. I explicitly removed the stale top-level `operation` field from the `Application` and forced a hard refresh. After that:

- the Deployment was created
- the PVC bound
- the pod started
- the app moved to `Synced Healthy`

### What I did
- Applied the live Argo `Application`.
- Diagnosed the PVC deadlock from `WaitForFirstConsumer`.
- Changed the PVC sync wave from `0` to `1`.
- Cleared the stale Argo `operation` field and forced a new refresh.

### Why
- The deployment could not proceed until the storage and deployment waves matched the semantics of the storage class.

### What worked
- The Vault/VSO dependency chain was healthy immediately.
- The pod started cleanly once Argo was allowed to apply the Deployment.

### What didn't work
- A naive sync-wave ordering around PVCs does not work with `WaitForFirstConsumer`.
- Argo can remain stuck on an earlier operation unless that stale operation is cleared.

### What I learned
- For PVCs that only become “healthy” when a pod exists, earlier sync waves can create deadlocks instead of safety.

### What should be done in the future
- Validate the live pod, public ingress, TLS, and login behavior.

## Step 6: Validate the live K3s CoinVault deployment end to end

With the application finally `Synced Healthy`, I collected the runtime evidence and ran the validation script.

The pod logs showed a healthy startup:

- tool catalog initialized
- static and asset handlers mounted
- server listening on `0.0.0.0:8080`
- `dbConfigured=true`
- `dbHealthy=true`

The pod description confirmed the expected contract:

- `coinvault:hk3s-0007`
- `coinvault-runtime` wired into the OIDC/session/MySQL env vars
- `coinvault-pinocchio` mounted at `/run/secrets/pinocchio`
- PVC mounted at `/data`

The first public validation attempt hit a transient TLS issue while cert-manager was still issuing. By the time I checked directly, the certificate was already valid from Let’s Encrypt, and cert-manager showed:

- `certificate/coinvault-tls` `READY=True`

Re-running [`validate-coinvault-k3s.sh`](/home/manuel/code/wesen/2026-03-27--hetzner-k3s/scripts/validate-coinvault-k3s.sh) then passed. That confirmed:

- Argo app healthy
- VSO destination secrets present
- `GET /healthz` works
- `/auth/login` redirects as expected

At that point CoinVault was live at:

- `https://coinvault.yolo.scapegoat.dev`

and functioning against:

- K3s Vault/VSO secret delivery
- K3s shared MySQL
- external Keycloak OIDC

### What I did
- Read the live pod logs and pod description.
- Verified the cert-manager certificate reached `READY=True`.
- Ran the public validation script successfully.

### Why
- The point of HK3S-0007 is not “manifests exist”; it is “the first real application is actually running on the new platform path.”

### What worked
- The app started healthy with database connectivity.
- The public hostname, TLS, and OIDC redirect path all worked.
- The secret wiring through VSO was correct.

### What didn't work
- The first public `curl` happened while the certificate was still being issued, which produced a transient TLS verification error.

### What I learned
- For fresh ingress rollouts, cert-manager timing can briefly make a healthy service look broken unless you separately verify issuance state.

### What should be done in the future
- Record cutover and rollback boundaries against the existing Coolify deployment, then decide whether and when to switch operators and users to the K3s endpoint.

## Step 7: Fix the post-rollout runtime config drift and verify CoinVault uses the mounted hosted profile registry

After the initial live rollout, the user hit an OpenAI `401 Unauthorized` during a real chat turn. The immediate suspicion was that CoinVault was not actually consuming the hosted Pinocchio config and profile material the way the K3s manifest intended.

The first part of the investigation clarified the runtime shape. The live deployment definitely mounted:

- `/run/secrets/pinocchio/profiles.yaml`
- `/run/secrets/pinocchio/config.yaml`

and the container process was definitely started with:

- `--profile-registries /run/secrets/pinocchio/profiles.yaml`

So the original “maybe the entrypoint is falling back to XDG and ignoring the mounted profile registry” theory was only half right. The container process was getting the intended CLI argument. But the live `/healthz` payload still reported:

- `chat.profile_registries = "./profile-registry.yaml"`

That meant the real bug was inside the application’s flag/value resolution path, not in the K3s manifest alone.

While reproducing that, a second failure surfaced. During a restart onto the newer CoinVault image, the pod began crashing before startup with:

- `Could not parse argument port as integer: strconv.Atoi: parsing "tcp://10.43.64.129:80": invalid syntax`

That turned out to be a Kubernetes service-link environment collision. Because the Service is named `coinvault`, Kubernetes was auto-injecting env vars such as:

- `COINVAULT_PORT=tcp://...`

CoinVault’s Glazed parser uses the `COINVAULT_*` namespace for app config, so it was accidentally treating that injected service-link value as an application port setting. That was separate from the profile-registry bug, but it had to be fixed first to get a stable pod again.

I fixed the Kubernetes-side collision in the K3s deployment by:

- adding `enableServiceLinks: false`
- adding an explicit `COINVAULT_SERVE_PORT=8080`

I also hardened the CoinVault entrypoint so it:

- prefers `COINVAULT_SERVE_PORT`
- does not rely on inherited bare `PORT`
- unsets inherited `PORT` before `exec`

Once the pod was stable again, I traced the real profile-registry issue more deeply. Running the same CoinVault binary inside the container with `--print-parsed-fields` showed that `profile-settings.profile-registries` was not always a single string. Because the value existed from both:

- env: `COINVAULT_PROFILE_REGISTRIES`
- cobra flag: `--profile-registries`

Glazed was merging it into a list-like value rather than a plain scalar string. CoinVault’s resolver in [`profile_settings.go`](/home/manuel/code/gec/2026-03-16--gec-rag/cmd/coinvault/cmds/profile_settings.go) still assumed a simple string field, so it silently fell back to the repo-local `./profile-registry.yaml`.

I fixed that by teaching the resolver to:

- read the raw field value from parsed values
- normalize string and list-backed shapes
- flatten them into the comma-separated registry-spec string the app expects

I added focused regression tests for:

- fallback from the default section
- precedence of the dedicated profile-settings section
- normalization of list-backed raw values

After rebuilding and reimporting the image, I rolled the deployment again and verified all of the following from the live pod:

- the running image ID matches the rebuilt image
- the process command line still contains `--profile-registries /run/secrets/pinocchio/profiles.yaml`
- `/healthz` now reports:
  - `chat.profile_registries = "/run/secrets/pinocchio/profiles.yaml"`

That closes the runtime-config drift loop. The deployment now uses the hosted profile registry source the ticket intended, rather than the repo fallback.

### What I did
- Inspected the live mounted secret files and compared them to the running process arguments.
- Used `/healthz` and in-container `--print-parsed-fields` runs to distinguish Kubernetes wiring bugs from CoinVault parser bugs.
- Disabled Kubernetes service links in the CoinVault pod template.
- Added `COINVAULT_SERVE_PORT` and hardened the entrypoint against inherited `PORT`.
- Patched CoinVault’s profile-settings resolver to normalize merged env plus flag values.
- Rebuilt and reimported the CoinVault image multiple times while isolating the two independent failures.
- Verified the live pod now reports the mounted hosted registry path.

### Why
- The app was healthy enough to start, but not healthy enough to trust. Until the runtime clearly consumed the mounted hosted registry, the OpenAI 401 could recur and the deployment would still be semantically wrong.

### What worked
- `/healthz` plus in-container `--print-parsed-fields` gave a precise way to separate manifest wiring, entrypoint behavior, and parser behavior.
- Disabling service links removed an entire class of namespace collision bugs for the `coinvault` app.
- The final rebuilt image and rollout cleanly switched the runtime source of truth to `/run/secrets/pinocchio/profiles.yaml`.

### What didn't work
- The first post-rollout assumption was too narrow: it looked like an XDG/config mount issue, but the deeper bug was the merged env plus flag field shape inside Glazed parsing.
- Reusing the generic `PORT` contract was too fragile for Kubernetes, especially with service-link env injection still enabled.

### What I learned
- In K8s, “the process was started with the correct flag” is not enough proof that the app is actually using the intended value. You need to inspect the app’s own resolved runtime state as well.
- Auto-injected Service env vars can collide badly with app-specific env prefixes when the Service name matches the app name.
- Glazed merged-value behavior matters when the same setting comes from both env and Cobra.

### What warrants a second pair of eyes
- The OpenAI 401 root symptom should still be rechecked with a real authenticated chat turn now that the runtime source path is corrected. The configuration path is fixed; the next verification is behavioral.

### What should be done in the future
- Record cutover and rollback boundaries.
- Re-run an authenticated CoinVault chat flow against the fixed runtime path and confirm the OpenAI request succeeds.

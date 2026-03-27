---
Title: Diary
Ticket: HK3S-0001
Status: active
Topics:
    - infra
    - kubernetes
    - terraform
    - gitops
DocType: reference
Intent: long-term
Owners: []
RelatedFiles:
    - Path: .gitignore
      Note: Prevents IDE-local state from leaking into git checkpoints
    - Path: .ttmp.yaml
      Note: Docmgr workspace configuration used by the ticket
    - Path: README.md
      Note: Repository context that informed the first deployment step
    - Path: ttmp/vocabulary.yaml
      Note: Extended with deployment-related topics for this ticket
ExternalSources: []
Summary: Step-by-step diary of ticket setup, deployment execution, questions, and outcomes.
LastUpdated: 2026-03-27T07:57:29.536192903-04:00
WhatFor: Preserve the chronological deployment narrative, including decisions, blockers, exact commands, and validation guidance.
WhenToUse: Update after each meaningful deployment step so another operator can reconstruct the rollout and review it quickly.
---


# Diary

## Goal

Capture the deployment of this repository to Hetzner as an ordered, reviewable sequence. Each step records what changed, why it was necessary, what blocked progress, and how to validate the result.

## Step 1: Create the deployment ticket and operator workflow

I created a dedicated docmgr ticket so this deployment has a durable control point instead of living only in shell history. The goal of this step was to turn the repository into a guided rollout with an explicit current step, a runbook, a task list, and a diary that can be updated after every meaningful action.

I also adjusted the workflow to include incremental git commits, because the user asked that progress be checkpointed as it happens. Since the repository started entirely uncommitted, the main care point was keeping IDE-local state out of the initial checkpoint while still allowing the actual project files to be committed.

### Prompt Context

**User prompt (verbatim):** "Create a new docmgr ticket to deploy this setup to hetzner, step by step, explaining to me what the current step is (and writing it up in your diary at each step) and asking me whatever needs to be answer."

**Follow-up user prompt (verbatim):** "make sure to commit things to git as you go as well."

**Follow-up user prompt (verbatim):** "you can check in all the initial files too"

**Assistant interpretation:** Create a deployment ticket for this repository, drive the rollout step by step, explain the active stage, and maintain a chronological diary as the work progresses.

**Inferred user intent:** Make the Hetzner deployment operationally explicit, inspectable, and easy to continue or review later.

**Commit (code):** `9e20730` — `chore: initialize hetzner k3s demo and deployment ticket`

### What I did
- Read the repository layout and `README.md` to identify the actual deployment sequence and external requirements.
- Read the `docmgr` and `diary` skill instructions and verified that this repo already had a configured `ttmp/` workspace.
- Added the missing ticket topics `infra`, `kubernetes`, `terraform`, and `gitops` to the local docmgr vocabulary.
- Created ticket `HK3S-0001` with a deployment plan, runbook, and diary.
- Replaced the empty generated templates with repo-specific content and a concrete task list.
- Added `.idea/` to `.gitignore` so local editor state does not leak into the initial commit.

### Why
- The deployment needs a tracked operating document before infrastructure changes begin.
- The repo requires several environment-specific values that cannot be inferred locally.
- Incremental git commits only help if the staged content is deliberate and reviewable.

### What worked
- `docmgr` was already initialized for this repo, so the ticket scaffold and supporting docs could be created cleanly.
- The repository README and Terraform variable definitions made the required deployment inputs clear without additional external research.

### What didn't work
- A plain `git add .` was not safe at the start of this step because the entire repository was untracked and included local IDE files under `.idea/`.
- My first frontmatter validation attempt used `docmgr validate frontmatter --doc ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/index.md --suggest-fixes`, which failed because `docmgr` resolved `--doc` relative to the docs root and looked for `/home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/ttmp/...`.

### What I learned
- The simplest supported bootstrap path is a public Git repository that both cloud-init and Argo CD can read directly.
- The blocking operator inputs are Hetzner credentials, SSH key material, admin CIDRs, Git repo details, DNS/domain settings, ACME email, and the PostgreSQL password.

### What was tricky to build
- The sharp edge was Git hygiene in a fully untracked repository. The symptom was that any broad staging command would have mixed local state, project source, and freshly created docmgr files together. I handled that by reading the generated ticket paths first, tightening `.gitignore`, and planning a targeted initial commit that includes project sources and ticket docs but excludes editor-only metadata.
- The other sharp edge was `docmgr` path resolution for validation. The symptom was a duplicated `ttmp/ttmp/...` path in the error output. The fix was to pass absolute document paths when validating frontmatter.

### What warrants a second pair of eyes
- The ticket naming choice `HK3S-0001` and the newly added topic vocabulary are sensible local defaults, but they should be renamed now if you have a stronger project-wide convention.
- The runbook currently assumes the public-repo bootstrap path described in the README. If you intend to use a private repository, the later steps will need to include Argo CD repo credentials.

### What should be done in the future
- Collect the operator-provided deployment values.
- Create the initial repository checkpoint in git.
- Prepare `terraform.tfvars` and move to the Terraform apply step.

### Code review instructions
- Start with `ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/index.md`, `ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/design-doc/01-deployment-plan.md`, and `ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/playbook/01-deployment-runbook.md`.
- Validate the ticket shape with `docmgr ticket list --ticket HK3S-0001`, `docmgr doc list --ticket HK3S-0001`, and `docmgr validate frontmatter --doc /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/reference/01-diary.md --suggest-fixes`.

### Technical details
- Commands run:
  - `docmgr status --summary-only`
  - `docmgr vocab add --category topics --slug infra --description 'Infrastructure and provisioning'`
  - `docmgr vocab add --category topics --slug kubernetes --description 'Kubernetes cluster bootstrap and operations'`
  - `docmgr vocab add --category topics --slug terraform --description 'Terraform infrastructure definitions and workflow'`
  - `docmgr vocab add --category topics --slug gitops --description 'GitOps bootstrapping and Argo CD deployment flow'`
  - `docmgr ticket create-ticket --ticket HK3S-0001 --title 'Deploy Hetzner K3s Demo' --topics infra,kubernetes,terraform,gitops`
  - `docmgr doc add --ticket HK3S-0001 --doc-type design-doc --title 'Deployment Plan'`
  - `docmgr doc add --ticket HK3S-0001 --doc-type playbook --title 'Deployment Runbook'`
  - `docmgr doc add --ticket HK3S-0001 --doc-type reference --title 'Diary'`
  - `docmgr validate frontmatter --doc /home/manuel/code/wesen/2026-03-27--hetzner-k3s/ttmp/2026/03/27/HK3S-0001--deploy-hetzner-k3s-demo/index.md --suggest-fixes`

## Step 2: Move from scaffolding to deployment input collection

With the initial repository checkpoint committed, the ticket can now act as the live deployment notebook. The current objective is narrower than the setup step: gather the environment-specific values that are still missing, confirm whether the Terraform defaults are acceptable, and then create the local `terraform.tfvars`.

This step is intentionally blocked on operator answers rather than more repo editing. The repository already tells us which values are required; the remaining work is to turn those into concrete answers we can safely apply.

### Prompt Context

**User prompt (verbatim):** (see Step 1)

**Follow-up user prompt (verbatim):** (see Step 1)

**Assistant interpretation:** Advance from ticket creation to the first real deployment gate by collecting the missing inputs and keeping the current step explicit in the docs.

**Inferred user intent:** Prevent Terraform work from starting until the deployment-specific values are known and documented.

### What I did
- Committed the initial repository state so subsequent deployment steps can be checkpointed cleanly.
- Promoted input collection to the active step in the ticket index and runbook.
- Reduced the next blocking work to the exact values required by `variables.tf` and `terraform.tfvars.example`.

### Why
- Terraform should not be run until the external values are explicit.
- A step-by-step workflow only stays useful if the active step is visible in the docs and git history.

### What worked
- The repository already exposes the required inputs clearly enough that no additional design work is needed before asking questions.

### What didn't work
- N/A

### What I learned
- The only values we truly need from the operator before a first apply are the secret-bearing or environment-specific ones; most infrastructure settings already have reasonable defaults.

### What was tricky to build
- The subtlety here was keeping the step boundary honest. It would have been easy to drift straight into editing `terraform.tfvars`, but that would have mixed inferred defaults with unknown operator choices. I kept the step focused by freezing the docs at the input-collection boundary and deferring value entry until the answers are explicit.

### What warrants a second pair of eyes
- If you already have a preferred server type, Hetzner region, hostname convention, or private-repo bootstrap path, that should be stated now before we generate the deployment values.

### What should be done in the future
- Collect the operator answers for the missing deployment inputs.
- Create `terraform.tfvars`.
- Move to the Terraform initialization and apply step.

### Code review instructions
- Review `variables.tf` and `terraform.tfvars.example` to confirm the question set is complete before any value entry happens.
- Confirm the active-step text in `index.md` and `playbook/01-deployment-runbook.md` matches the real deployment state.

### Technical details
- Inputs derived from:
  - `variables.tf`
  - `terraform.tfvars.example`
  - `README.md`

## Step 3: Resolve what can be inferred locally and isolate the remaining decisions

I took the user-provided answers and checked which ones could be resolved directly from the local environment. That narrowed the deployment gate substantially: the SSH public key exists locally, the current public IP can seed a sensible firewall default, the Git revision can remain `main`, and the `cpx31` override is clear.

The remaining blockers are not all obvious from the variable names alone. The most important discoveries were that the current Git remote is SSH, which cloud-init cannot use without additional credentials on the new server, and that the requested 1Password lookup cannot proceed until the `op` CLI has a live desktop-app session or another valid sign-in path.

### Prompt Context

**User prompt (verbatim):** "ssh key:  ~/.ssh/id_ed25519.pub 
hetzner token: api credential hetzner k3s deploy in 1password (use cli)
3. dunno what to chose
git: github.com/wesen/2026-03-27--hetzner-k3s
5. k3s.scapegoat.com, dunno about acme_email and subdomain? I probably need the server IP anyway before cnfigure this?
6. you generate
7. cpx31"

**Assistant interpretation:** Use the provided local SSH key, read the Hetzner token from 1Password via CLI, propose a reasonable admin CIDR, infer the intended Git and hostname settings, generate the PostgreSQL password, and identify any remaining missing values.

**Inferred user intent:** Reduce the open deployment questionnaire to only the values that genuinely need an explicit decision.

### What I did
- Verified that `~/.ssh/id_ed25519.pub` exists locally.
- Checked that the `op` CLI is installed and attempted to inspect the named 1Password item without printing secret material.
- Read the current public IP from `https://api.ipify.org` to propose a candidate admin firewall CIDR.
- Read the local Git remote to see whether the repo URL the server needs should be SSH or HTTPS.
- Mapped the user-provided hostname input to the Terraform variables to determine whether `k3s.scapegoat.com` refers to `base_domain` or the final full host.

### Why
- These checks eliminate guesswork before writing `terraform.tfvars`.
- The repo URL and hostname shape directly affect whether bootstrap succeeds.

### What worked
- The SSH public key path resolved cleanly to a real key.
- The current public IP was discoverable and provides a practical `admin_cidrs` default candidate.
- The Git remote made the bootstrap risk visible before deployment.

### What didn't work
- `op item get 'hetzner k3s deploy' --vault 'api credential' --format json` failed with: `[ERROR] 2026/03/27 08:11:22 error initializing client: connecting to desktop app: cannot connect to 1Password app, make sure it is running`

### What I learned
- The simplest workable repo URL for this stack is a public HTTPS clone URL, not the current SSH remote.
- The desired host must be decided before apply even though DNS is only updated after the server IP exists, because the host is embedded in the bootstrapped Argo CD application values.
- A reasonable first `admin_cidrs` value is the current public IP as `/32`, which in this environment is `98.175.153.62/32`.

### What was tricky to build
- The tricky part was separating “unknown because the user has not answered yet” from “unknown because the existing value is subtly invalid for bootstrap.” The Git remote is the best example: `git@github.com:wesen/2026-03-27--hetzner-k3s.git` is a valid local remote, but it is not a valid anonymous clone URL for a fresh server. I handled that by checking the actual remote and translating it into the deployment-safe requirement.

### What warrants a second pair of eyes
- If the repository is private, the bootstrap design changes materially because cloud-init and Argo CD will both need credentials.
- If the admin IP is dynamic or shared, using a single `/32` CIDR may cause lockouts later and should be replaced with a more stable range or a deliberate firewall update workflow.

### What should be done in the future
- Start or re-authenticate the 1Password app/session so the Hetzner token can be read through `op`.
- Confirm whether the intended hostname is `k3s.scapegoat.com` or `demo.k3s.scapegoat.com`.
- Provide the ACME email.
- Confirm whether `admin_cidrs = ["98.175.153.62/32"]` is acceptable.
- Create `terraform.tfvars` with a generated PostgreSQL password once the remaining answers are fixed.

### Code review instructions
- Review `variables.tf` and `main.tf` together to confirm the final hostname composition and repo URL expectations.
- Review `playbook/01-deployment-runbook.md` to confirm the added notes match the actual bootstrap constraints.

### Technical details
- Commands run:
  - `test -f ~/.ssh/id_ed25519.pub && sed -n '1p' ~/.ssh/id_ed25519.pub`
  - `command -v op && op --version`
  - `curl -fsSL https://api.ipify.org`
  - `git remote -v`
  - `op item get 'hetzner k3s deploy' --vault 'api credential' --format json | jq -r '.title, (.fields[] | [.id, .label, .type] | @tsv)'`

## Step 4: Convert the operator answers into concrete deployment values

The input set is now mostly fixed. The user confirmed the local SSH key path, accepted the current public IP as the admin firewall CIDR, made the repository public, chose the final hostname `k3s.scapegoat.com`, and kept the `cpx31` server type. That narrows the unresolved inputs to only two items: the ACME email and successful token retrieval through 1Password.

This is the point where the variable model becomes concrete. `k3s.scapegoat.com` maps cleanly to `base_domain = "scapegoat.com"` and `app_subdomain = "k3s"`, and the Git bootstrap path can now use the public HTTPS clone URL instead of the local SSH remote.

### Prompt Context

**User prompt (verbatim):** "op is running, git is public now. ips are fine, k3s.scapegoat.com. what's an ACME email?"

**Assistant interpretation:** Record the confirmed deployment choices, retry token access through 1Password, and explain the remaining ACME email field before asking for the final value.

**Inferred user intent:** Finish the last ambiguous setup details so `terraform.tfvars` can be created with minimal friction.

### What I did
- Marked the admin CIDR, hostname, public repo path, and `cpx31` server type as confirmed ticket inputs.
- Mapped `k3s.scapegoat.com` onto the Terraform variables `base_domain = "scapegoat.com"` and `app_subdomain = "k3s"`.
- Retried the 1Password item access after the user indicated that `op` is running.

### Why
- These confirmations remove the main remaining ambiguity from `terraform.tfvars`.
- The ACME email field is easy to answer once its purpose is explicit.

### What worked
- The hostname choice is now settled and consistent with the repo’s variable model.
- The Git bootstrap path can use a public HTTPS URL, which matches the simplest supported deployment path.

### What didn't work
- `op item get 'hetzner k3s deploy' --vault 'api credential' --format json | jq -r '.title, (.fields[] | [.id, .label, .type] | @tsv)'` is still pending on interactive 1Password access at the time of this diary update.

### What I learned
- The last user-facing ambiguity is not DNS timing but the purpose of the ACME contact email.

### What was tricky to build
- The subtlety here is that the hostname answer looked like a base domain at first glance, but it is actually the final host. I resolved that by mapping the final host back into the repo’s two-part variable model instead of treating the whole string as `base_domain`.

### What warrants a second pair of eyes
- If `scapegoat.com` has other automation around ACME or DNS, use an email address that the operator actually monitors rather than a throwaway personal address.

### What should be done in the future
- Provide the ACME email.
- Complete the 1Password token retrieval.
- Generate the PostgreSQL password and write local `terraform.tfvars`.

### Code review instructions
- Review `variables.tf` and `playbook/01-deployment-runbook.md` to confirm the final host mapping and confirmed values are correct.

### Technical details
- Confirmed values:
  - `admin_cidrs = ["98.175.153.62/32"]`
  - `repo_url = "https://github.com/wesen/2026-03-27--hetzner-k3s.git"`
  - `base_domain = "scapegoat.dev"`
  - `app_subdomain = "k3s"`
  - `server_type = "cpx31"`

## Step 5: Materialize local deployment secrets and initialize Terraform

The deployment inputs are now complete enough to leave the questionnaire phase. I retrieved the Hetzner token from 1Password, generated a PostgreSQL password, wrote a local `terraform.tfvars`, and ran the first Terraform commands needed to verify that the configuration is ready to plan.

One important correction landed during this step: the base domain is `scapegoat.dev`, not `scapegoat.com`, which means the final app host is `k3s.scapegoat.dev`. That correction was applied before generating `terraform.tfvars`, so the local deployment values are internally consistent.

### Prompt Context

**User prompt (verbatim):** "it's in the Private. acme: wesen@ruinwesen.com"

**Follow-up user prompt (verbatim):** "it's scapegoat.dev btw"

**Assistant interpretation:** Use the `Private` 1Password vault to resolve the Hetzner token, record the ACME email, correct the base domain, and move from input collection to Terraform-ready local configuration.

**Inferred user intent:** Finish the secret-bearing setup work and get the deployment to the point where Terraform can safely plan and apply.

### What I did
- Resolved the 1Password item from the `Private` vault and revealed the concealed `credential` field for local use.
- Generated a PostgreSQL password locally.
- Created `terraform.tfvars` with the token, SSH key, admin CIDR, public HTTPS repo URL, corrected `.dev` base domain, ACME email, and generated database password.
- Ran `terraform init`.
- Ran `terraform validate`.
- Updated the ticket to make Terraform planning the active step.

### Why
- `terraform apply` should only happen after the local secrets file exists and Terraform has been initialized successfully.
- The corrected base domain had to be applied before the local variables file was written, otherwise the bootstrap manifests would target the wrong host.

### What worked
- The 1Password CLI workflow succeeded once the correct vault name was used.
- `terraform init` completed successfully.
- `terraform validate` reported a valid configuration.

### What didn't work
- The first attempt to address the vault by the guessed family-vault name failed because that vault name was not present in the CLI-visible account context.

### What I learned
- The deployment no longer has any unanswered input questions for the Terraform phase.
- The repo's current `.gitignore` ignores `.terraform.lock.hcl`, so the provider lock file created by `terraform init` remains local instead of being checkpointed.

### What was tricky to build
- The main sharp edge was avoiding a stale domain value after the late correction from `.com` to `.dev`. The symptom would have been a silently wrong ingress host embedded into the cloud-init bootstrap. I handled that by treating the correction as authoritative and regenerating the local deployment values only after updating the mapped `base_domain`.

### What warrants a second pair of eyes
- If the `.terraform.lock.hcl` file is intended to be versioned later, the current `.gitignore` will need to change before that can happen.
- The generated PostgreSQL password exists only in the ignored local `terraform.tfvars`; if you want a second copy in a secret manager, that should happen before apply or immediately after.

### What should be done in the future
- Run `terraform plan`.
- If the plan is correct, run `terraform apply`.
- Capture the server IP and move to the DNS and cloud-init monitoring steps.

### Code review instructions
- Review `terraform.tfvars.example`, `variables.tf`, and the updated runbook to confirm the resolved variable set is coherent.
- Re-run `terraform init` and `terraform validate` in the repo root if you need to reproduce the local-preparation step.

### Technical details
- Commands run:
  - `op item get 'hetzner k3s deploy' --vault 'Private' --format json | jq -r '.title, (.fields[] | [.id, .label, .type] | @tsv)'`
  - `op item get 7c5e27xsunmsv5sxyd7fuf7xwq --vault 'Private' --fields credential --reveal`
  - `openssl rand -base64 30`
  - `terraform init`
  - `terraform validate`

## Step 6: Recover from Hetzner apply-time constraints

The first live Terraform apply did not fail generically; it exposed two concrete Hetzner account/runtime constraints. First, the SSH public key already existed in the account, which required importing that key into Terraform state and normalizing the local key value so Terraform would stop trying to replace it. After that recovery, the next apply attempt got further but failed because `cpx31` is no longer orderable in `fsn1`.

This is now a genuine operator choice, not a tooling issue. The deployment can continue immediately once a replacement server type or location is selected, and the partial infrastructure state is stable: the firewall exists, the SSH key is managed in state, and no server resource was created.

### Prompt Context

**User prompt (verbatim):** (see Step 5)

**Assistant interpretation:** Continue the deployment after local preparation, recover from any Terraform apply errors, and keep the ticket synchronized with the actual Hetzner-side state.

**Inferred user intent:** Get the infrastructure created even if the first apply surfaces real provider constraints that require adaptation.

### What I did
- Ran `terraform plan` and confirmed the intended firewall, SSH key, and server shape.
- Ran `terraform apply`, which created the firewall but failed on duplicate SSH key creation.
- Queried Hetzner for existing SSH keys, identified the matching key ID `109828147`, and imported it into Terraform state.
- Corrected the local `ssh_public_key` value to remove the trailing comment so Terraform would stop forcing key replacement.
- Re-ran `terraform plan`, confirming the SSH key was now only an in-place rename.
- Re-ran `terraform apply`, which updated the SSH key name and then failed during server creation because `cpx31` is unavailable in `fsn1`.
- Queried Hetzner server type availability to collect concrete replacement options.

### Why
- The apply failures were provider-specific and recoverable; the right move was to adapt state and inputs rather than abandon the run.
- Asking the operator to choose from concrete available options is better than asking for another blind guess.

### What worked
- The duplicate SSH key issue was resolved cleanly by importing the existing Hetzner key.
- The firewall was created successfully.
- The SSH key is now managed in Terraform state with the desired resource name.
- Hetzner availability data provided clear next-step options.

### What didn't work
- `terraform apply -auto-approve -no-color` first failed with:
  - `SSH key not unique`
  - `Error code: uniqueness_error`
  - `Status code: 409`
- After importing the key and correcting the local key format, `terraform apply -auto-approve -no-color` failed again with:
  - `Server Type "cpx31" is unavailable in "fsn1" and can no longer be ordered`

### What I learned
- The local key comment matters because Hetzner stores the imported public key without it, and Terraform treats that mismatch as a replacement-level diff.
- `cpx31` still appears in pricing catalogs for several locations, but Hetzner rejects ordering it in `fsn1` for this account/region combination.

### What was tricky to build
- The tricky part was separating mutable local config issues from hard provider constraints. The SSH key problem looked like a create failure, but the underlying fix was state reconciliation plus public-key normalization. The server-type problem is different: Terraform and the repo config are both structurally fine, but the chosen SKU/location pair is no longer orderable. Treating those as the same kind of failure would have obscured the correct recovery path.

### What warrants a second pair of eyes
- If preserving the original `cpx31` performance profile matters more than staying in `fsn1`, choose a different location such as `nbg1` or `hel1`.
- If staying in `fsn1` matters more, `cpx32` is the closest currently orderable replacement in the same broad family.

### What should be done in the future
- Choose one of the available server type/location combinations.
- Update local deployment values accordingly.
- Re-run `terraform apply`.
- Capture the server IP and continue with DNS and cloud-init monitoring.

### Code review instructions
- Review the current step notes in `index.md` and `playbook/01-deployment-runbook.md`.
- Reproduce the recovered Terraform state with `terraform state list` and `terraform show -no-color`.

### Technical details
- Commands run:
  - `terraform plan -no-color`
  - `terraform apply -auto-approve -no-color`
  - `terraform state list`
  - `terraform show -no-color`
  - `curl -fsSL -H "Authorization: Bearer $TOKEN" https://api.hetzner.cloud/v1/ssh_keys`
  - `terraform import hcloud_ssh_key.default 109828147`
  - `curl -fsSL -H "Authorization: Bearer $TOKEN" 'https://api.hetzner.cloud/v1/server_types?per_page=100'`

## Step 7: Create the server after choosing an orderable Hetzner SKU

Once the user picked `cpx32` in `fsn1`, the blocked Terraform phase became straightforward again. I updated the local deployment values, re-ran `terraform apply`, and Hetzner successfully created the server. Terraform now reports the concrete SSH command and both public IPs, which makes DNS and cloud-init monitoring the active deployment phase.

The node was not yet accepting SSH connections on the first immediate probe after creation, which is normal during very early boot. That means the deployment is no longer blocked on infrastructure provisioning, but it is not yet ready for Kubernetes validation.

### Prompt Context

**User prompt (verbatim):** "cpx32 fsn1"

**Assistant interpretation:** Use `cpx32` in `fsn1` as the replacement for the unavailable `cpx31` offering and continue the Hetzner apply.

**Inferred user intent:** Unblock infrastructure creation with the smallest practical change.

### What I did
- Updated the local `server_type` override from `cpx31` to `cpx32`.
- Re-ran `terraform apply`.
- Captured the resulting Terraform outputs:
  - app URL: `https://k3s.scapegoat.dev`
  - IPv4: `91.98.46.169`
  - IPv6: `2a01:4f8:c013:c4d6::1`
  - SSH command: `ssh root@91.98.46.169`
- Attempted immediate SSH access to the server and observed that port 22 was not yet accepting connections.

### Why
- The `cpx31`/`fsn1` combination was a hard provider-side blocker; changing to `cpx32` preserved location while restoring orderability.
- Capturing the IP and SSH details is necessary for the next operational steps.

### What worked
- `terraform apply` completed successfully after the server type change.
- The Hetzner server now exists and Terraform outputs are populated.

### What didn't work
- Immediate SSH attempts right after apply returned:
  - `ssh: connect to host 91.98.46.169 port 22: Connection refused`

### What I learned
- The deployment is now in the post-provision bootstrap phase rather than the infrastructure creation phase.
- DNS can and should be configured now because the final server IPv4 is known.

### What was tricky to build
- The main subtlety was knowing when an apply success still does not mean the node is operationally ready. Terraform returning successfully only confirms the resource exists; it does not guarantee that SSH or cloud-init are ready. I handled that by probing SSH immediately and carrying the “connection refused” result forward as part of the active step instead of assuming bootstrap had begun cleanly.

### What warrants a second pair of eyes
- None on the Terraform side right now; the next risk surface is bootstrap timing and application-level readiness on the node.

### What should be done in the future
- Create the DNS record for `k3s.scapegoat.dev`.
- Retry SSH until the node is reachable.
- Watch cloud-init to completion.
- Continue with kubeconfig and Argo CD validation.

### Code review instructions
- Review `terraform output -no-color` and the updated current-step sections in the ticket docs.
- Retry the SSH and cloud-init commands once the node starts accepting connections.

### Technical details
- Commands run:
  - `terraform apply -auto-approve -no-color`
  - `terraform output -no-color`
  - `ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 root@91.98.46.169 'cloud-init status --wait && echo CLOUD_INIT_DONE'`
  - `ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 root@91.98.46.169 'tail -n 120 /var/log/cloud-init-output.log'`

## Step 8: Fix the repo-driven bootstrap failure and narrow the deployment blocker to DNS

The cloud-init failure turned out to be caused by the repository itself, not by Kubernetes or Hetzner. The server-side Docker build failed because `app/go.sum` was missing the module checksum for `github.com/lib/pq`. I fixed that locally, pushed the corrected `main` branch to GitHub, and reran the bootstrap script directly on the node. The rerun passed the build stage, imported the image into K3s, created the Argo CD application, and allowed the cluster to converge much further.

At this point the deployment is operational inside the cluster: the node is `Ready`, PostgreSQL is healthy, the app pod is running, the app responds through Traefik over plain HTTP when the correct Host header is used, and cert-manager has created the HTTP-01 solver resources. The only remaining blocker is external DNS propagation for `k3s.scapegoat.dev`, which is preventing the ACME self-check from succeeding.

### Prompt Context

**User prompt (verbatim):** (see Step 7)

**Assistant interpretation:** Continue the rollout after successful server creation, diagnose the cloud-init error, fix the underlying repo issue, and resume bootstrap until the remaining blocker is truly external.

**Inferred user intent:** Get the environment as close to fully working as possible inside the current turn, not just stop at “server created.”

### What I did
- Inspected `cloud-init` logs and identified the exact failing command on the server-side Docker build.
- Confirmed that `app/go.sum` was missing the checksum entry for `github.com/lib/pq`.
- Ran `go mod tidy` in `app/` to repair the module metadata.
- Committed the fix and pushed local `main` to GitHub so the public repo matched the bootstrap target.
- Reran `/usr/local/bin/bootstrap-k3s-demo.sh` on the server and tailed `/root/bootstrap-rerun.log`.
- Verified cluster readiness from both the server and a fetched local kubeconfig.
- Confirmed the app responds correctly via Traefik over HTTP using `Host: k3s.scapegoat.dev`.
- Confirmed the ACME challenge is pending specifically because DNS does not resolve yet.

### Why
- The server clones from the public GitHub repo, so a local-only fix would not have unblocked the bootstrap.
- Once the internal app path was healthy, the remaining blocker could be isolated to DNS and certificate issuance.

### What worked
- The `go.sum` fix resolved the Docker build failure on the server.
- The bootstrap rerun completed the image build/import and created the Argo CD application successfully.
- `kubectl get nodes` reports the node as `Ready`.
- PostgreSQL, the app pod, Traefik ingress, and the ACME solver pod are all running.
- The app is reachable at `http://91.98.46.169/` when using `Host: k3s.scapegoat.dev`.

### What didn't work
- The original `cloud-init` run failed with:
  - `main.go:13:2: missing go.sum entry for module providing package github.com/lib/pq`
- The TLS challenge is currently blocked with:
  - `Waiting for HTTP-01 challenge propagation ... lookup k3s.scapegoat.dev ... no such host`

### What I learned
- The deployment repo and the deployment target repo must stay in sync; local commits are not enough when cloud-init clones from GitHub.
- The remaining blocker is fully external now: DNS propagation for the chosen hostname.

### What was tricky to build
- The sharp edge was that the failure surfaced on the server during cloud-init, but the real fix had to happen locally, be committed, and be pushed before any retry on the node would matter. Treating it as a pure server-side failure would have led to useless reruns against the same broken revision. I handled that by tracing the failing build output back to the repo contents, fixing the source of truth, and only then rerunning bootstrap.

### What warrants a second pair of eyes
- `demo-stack` currently reports `Healthy` but `OutOfSync` in Argo CD. The workload itself is functioning, and the next important thing is DNS/TLS, but the sync status should be checked again after the certificate settles.
- The task “Watch cloud-init complete successfully” remains unchecked because the original cloud-init service did fail, even though the manual rerun recovered the environment operationally.

### What should be done in the future
- Create and propagate the DNS `A` record for `k3s.scapegoat.dev`.
- Wait for cert-manager to complete the HTTP-01 challenge and issue the certificate.
- Recheck Argo CD sync status and HTTPS reachability.
- Record the final validation state.

### Code review instructions
- Start with `app/go.sum` and the Step 8 diary entry to understand the bootstrap failure and fix.
- Validate the current runtime with:
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl get nodes -o wide`
  - `ssh root@91.98.46.169 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml && kubectl -n demo get pods,svc,ingress,certificate,challenge,order'`
  - `curl -H 'Host: k3s.scapegoat.dev' http://91.98.46.169/`

### Technical details
- Commands run:
  - `go mod tidy`
  - `git push origin main`
  - `ssh root@91.98.46.169 'nohup /usr/local/bin/bootstrap-k3s-demo.sh >/root/bootstrap-rerun.log 2>&1 &'`
  - `ssh root@91.98.46.169 'tail -n 200 /root/bootstrap-rerun.log'`
  - `./scripts/get-kubeconfig.sh 91.98.46.169`
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl get nodes -o wide`
  - `curl -H 'Host: k3s.scapegoat.dev' http://91.98.46.169/`
  - `ssh root@91.98.46.169 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml && kubectl -n demo describe challenge demo-app-tls-1-2437261689-271864726'`

## Step 9: Apply the DigitalOcean DNS records and reduce the blocker to propagation

I applied the missing DNS change in the separate Terraform infrastructure repository at `~/code/wesen/terraform`, because that repo already owns the `scapegoat.dev` DigitalOcean zone. The change added the exact host record needed for this deployment, `k3s.scapegoat.dev -> 91.98.46.169`, and also the requested wildcard `*.yolo.scapegoat.dev -> 91.98.46.169` on the same server.

The authoritative DigitalOcean nameserver is already serving both records, which means the Terraform change itself is complete and correct. The remaining blocker is narrower now: recursive DNS and cert-manager’s self-check need a bit of time to observe the new `k3s` record so the ACME HTTP-01 challenge can complete and TLS can be issued.

### Prompt Context

**User prompt (verbatim):** "catn you add the IP to DO dns I think the setup is in ~/code/wesen/terraform? 91.98.46.169"

**Follow-up user prompt (verbatim):** "also add a wildcard for *.yolo.scapegoat.dev for this server"

**Assistant interpretation:** Modify the existing DigitalOcean DNS Terraform zone to point `k3s.scapegoat.dev` and `*.yolo.scapegoat.dev` at the Hetzner server, then apply and verify the change.

**Inferred user intent:** Finish the external DNS dependency directly in the existing infrastructure-as-code repo so certificate issuance can proceed.

### What I did
- Located the managed DigitalOcean zone in `~/code/wesen/terraform/dns/zones/scapegoat-dev/envs/prod`.
- Added Terraform-managed `A` records for:
  - `k3s.scapegoat.dev -> 91.98.46.169`
  - `*.yolo.scapegoat.dev -> 91.98.46.169`
- Ran Terraform `init`, `plan`, and `apply` in that DNS workspace.
- Verified the authoritative DigitalOcean nameserver returns both new records.
- Committed and pushed the DNS repo change so the zone update is durable in source control.

### Why
- The DNS zone is already owned by Terraform in a separate repo, so the right fix was to extend that source of truth instead of creating an out-of-band record manually.
- The wildcard `*.yolo` request can be satisfied cleanly in the same change.

### What worked
- Terraform created both DigitalOcean DNS records successfully.
- `@ns1.digitalocean.com` resolves both `k3s.scapegoat.dev` and `foo.yolo.scapegoat.dev` to `91.98.46.169`.
- The DNS repo change is committed and pushed as `c24b1f1`.

### What didn't work
- My local default recursive resolver did not return `k3s.scapegoat.dev` immediately after the apply, even though the authoritative DigitalOcean nameserver already had the new record.

### What I learned
- The remaining blocker is no longer “DNS record missing”; it is “recursive DNS propagation not complete enough for cert-manager’s HTTP-01 self-check.”

### What was tricky to build
- The subtlety here was verifying the right layer of DNS. A normal `dig` against the default resolver still returned nothing for `k3s.scapegoat.dev`, which could have looked like a failed apply. Querying `@ns1.digitalocean.com` showed the authoritative zone was already correct, so the right interpretation is propagation delay rather than Terraform drift or a bad zone change.

### What warrants a second pair of eyes
- None on the Terraform DNS side; the authoritative zone state is already correct.

### What should be done in the future
- Wait for recursive DNS propagation.
- Recheck the cert-manager challenge, certificate, and order resources.
- Verify `https://k3s.scapegoat.dev` end to end.

### Code review instructions
- Review the DNS repo change at `~/code/wesen/terraform/dns/zones/scapegoat-dev/envs/prod/main.tf`.
- Validate authoritative DNS with:
  - `dig +short @ns1.digitalocean.com k3s.scapegoat.dev`
  - `dig +short @ns1.digitalocean.com foo.yolo.scapegoat.dev`

### Technical details
- Terraform DNS apply created:
  - `digitalocean_record.records["k3s_a"]` with record id `1813844261`
  - `digitalocean_record.records["wildcard_yolo_a"]` with record id `1813844262`

## Step 10: Verify public HTTPS and capture the residual post-deploy drift

After the DNS change propagated publicly, the remaining certificate and ingress path cleared. Public resolvers returned `k3s.scapegoat.dev -> 91.98.46.169`, cert-manager marked `demo-app-tls` as ready, and `curl -I https://k3s.scapegoat.dev` returned `HTTP/2 200`. That is the first fully end-to-end success state for the deployment.

One operational wrinkle remains: Argo CD reports the `demo-stack` application as `Healthy` but still `OutOfSync`, with the PostgreSQL StatefulSet listed as the unsynced resource. The workload itself is functioning, so this is no longer a go-live blocker, but it is worth treating as residual GitOps drift rather than silently calling the environment perfectly clean.

### Prompt Context

**User prompt (verbatim):** "ok, continue"

**Assistant interpretation:** Keep driving the deployment through propagation, certificate issuance, and final validation until the environment is working or the next real blocker appears.

**Inferred user intent:** Reach a genuinely usable deployed state, not just infrastructure existence.

### What I did
- Confirmed that public recursive DNS now resolves `k3s.scapegoat.dev`.
- Verified that the application serves over HTTPS at `https://k3s.scapegoat.dev`.
- Verified `certificate/demo-app-tls` is `Ready=True`.
- Verified the app and Postgres pods are both `Running` and the ingress has the expected host and address.
- Checked the Argo CD application status after the deployment reached steady state.

### Why
- HTTPS reachability is the real deployment completion condition for this stack.
- Residual GitOps drift should be called out explicitly rather than hidden behind a healthy app status.

### What worked
- Public DNS propagation completed.
- cert-manager completed the ACME flow and issued the certificate.
- `https://k3s.scapegoat.dev` responds successfully.
- The K3s node, app pod, PostgreSQL pod, ingress, and certificate are all in a working state.

### What didn't work
- CoreDNS on the cluster initially continued to return NXDOMAIN even after public DNS propagation, which required a runtime CoreDNS forwarder adjustment before the in-cluster self-check path caught up cleanly.

### What I learned
- This deployment is operationally successful even though the original cloud-init run failed and Argo CD still shows a residual `OutOfSync` resource.
- The cleanest post-deploy follow-up is not “make it work” anymore; it is “explain or eliminate the remaining GitOps drift on the PostgreSQL StatefulSet.”

### What was tricky to build
- The subtle part of the final stretch was distinguishing end-user success from control-plane perfection. Public HTTPS and a ready certificate are the real service outcome, but the GitOps control plane still has a mismatch to explain. Treating those as separate concerns made it possible to close the deployment confidently without losing sight of the remaining drift.

### What warrants a second pair of eyes
- The `demo-stack-postgres` StatefulSet drift in Argo CD.
- The runtime CoreDNS override, which was a practical deployment fix but not yet codified in repo-managed infrastructure.

### What should be done in the future
- Inspect the Argo CD diff for `demo-stack-postgres`.
- Decide whether to codify the CoreDNS forwarder behavior or solve the node resolver issue in infrastructure config.
- Record the final residual risks and cleanup choices.

### Code review instructions
- Validate the final service with:
  - `curl -I https://k3s.scapegoat.dev`
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl -n demo get pods,svc,ingress,certificate`
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl -n argocd get applications`

### Technical details
- Final validation commands:
  - `dig +short k3s.scapegoat.dev`
  - `curl -I https://k3s.scapegoat.dev`
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl -n demo get pods,svc,ingress,certificate`
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl -n argocd get application demo-stack -o yaml`

## Step 11: Expose Argo CD publicly on argocd.yolo.scapegoat.dev

The user asked for a real Argo CD hostname instead of relying on local port-forwarding. The wildcard DNS record `*.yolo.scapegoat.dev -> 91.98.46.169` was already in place, so the remaining work was inside the cluster: make `argocd-server` safe to run behind an ingress, create a Traefik ingress for `argocd.yolo.scapegoat.dev`, and let cert-manager issue a certificate for that host.

I also treated this as a durability issue, not just a live-cluster tweak. The repo now has an optional `argocd_host` variable, and cloud-init applies the Argo CD ingress automatically when that value is set. That means a rebuild of the node can preserve the public Argo CD endpoint instead of losing it on the next reprovision.

### Prompt Context

**User prompt (verbatim):** "can we expose it as argocd.yolo.scapegoat.dev ?"

**Assistant interpretation:** Add a proper public HTTPS ingress for Argo CD on the existing wildcard DNS instead of telling the user to keep using port-forward.

**Inferred user intent:** Make Argo CD usable from the browser like the app itself, with a stable hostname and certificate.

### What I did
- Added an optional Terraform variable `argocd_host`.
- Passed that value into `cloud-init.yaml.tftpl`.
- Updated cloud-init so that, when `argocd_host` is set, it:
  - patches `argocd-cmd-params-cm` with `server.insecure: "true"`
  - restarts `argocd-server`
  - creates an `Ingress` named `argocd-server-public` in the `argocd` namespace
  - requests TLS from the existing `letsencrypt-prod` `ClusterIssuer`
- Set the local deployment value to `argocd.yolo.scapegoat.dev`.
- Applied the same patch and ingress directly to the running cluster so the current server matches the repo state immediately.
- Verified the certificate and public HTTPS response.

### Why
- Port-forward is fine for bootstrap but poor as the steady-state operator path.
- The wildcard DNS record already covered `argocd.yolo.scapegoat.dev`, so this could be implemented without any further external DNS work.
- Making the behavior part of Terraform plus cloud-init avoids configuration drift on future reprovisioning.

### What worked
- `argocd-server` accepted the `server.insecure` change and came back healthy after restart.
- Traefik routed `argocd.yolo.scapegoat.dev` to the Argo CD UI.
- cert-manager issued `certificate/argocd-server-public-tls`.
- `curl -I https://argocd.yolo.scapegoat.dev` returned `HTTP/2 200`.

### What didn't work
- The first long-running shell that combined the restart, apply, and waits was not the best way to observe progress; checking the resulting resources directly was more reliable than waiting on the bundled command stream.

### What I learned
- The existing wildcard DNS record was enough to expose additional operator endpoints on the same node without another round trip to the DNS repo.
- For this upstream Argo CD install path, explicitly forcing insecure-behind-ingress mode is the safer way to avoid redirect or protocol confusion at the ingress layer.
- Because `hcloud_server.user_data` is part of the Terraform-managed server definition, codifying this bootstrap change means a future `terraform apply` would replace the current node unless that replacement is intentionally accepted.

### What was tricky to build
- The subtlety was not the ingress object itself but the Argo CD server mode behind that ingress. Exposing Argo CD without changing `server.insecure` risks awkward redirect and protocol behavior. I handled that by codifying the server-mode change together with the ingress rather than treating the hostname as a Traefik-only concern.

### What warrants a second pair of eyes
- Whether you want to keep Argo CD publicly exposed long term, or later restrict it with additional auth controls, IP filtering, or SSO.
- The residual `demo-stack-postgres` drift in Argo CD, which is easier to inspect now that the UI is directly reachable.

### What should be done in the future
- Log into `https://argocd.yolo.scapegoat.dev` and inspect the `demo-stack-postgres` diff.
- Decide whether the public Argo CD ingress should stay open as-is or be tightened with additional controls.
- Consider codifying the CoreDNS resolver workaround next, since that remains a manual cluster-side adjustment.

### Code review instructions
- Review:
  - `variables.tf`
  - `main.tf`
  - `cloud-init.yaml.tftpl`
  - `README.md`
- Validate with:
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl -n argocd get ingress,certificate`
  - `curl -I https://argocd.yolo.scapegoat.dev`
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl -n argocd get configmap argocd-cmd-params-cm -o yaml`

### Technical details
- Live cluster commands:
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl -n argocd patch configmap argocd-cmd-params-cm --type merge -p '{"data":{"server.insecure":"true"}}'`
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl -n argocd rollout restart deployment/argocd-server`
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl apply -f -` with the `argocd-server-public` ingress manifest
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl -n argocd wait --for=condition=Ready certificate/argocd-server-public-tls --timeout=300s`
  - `curl -I https://argocd.yolo.scapegoat.dev`
- Terraform validation:
  - `terraform validate -no-color`
  - `terraform plan -no-color` showed `hcloud_server.node` replacement because `user_data` changed

## Step 12: Clean up local git hygiene and freeze the next action

After exposing Argo CD publicly, the only local repo noise left was an untracked `.envrc`. That file is clearly workstation-local state and does not belong in deployment history, so I excluded it from git. This is a small housekeeping step, but it matters because the user explicitly asked for incremental commits as the deployment progresses, and those commits should stay reviewable and free of local shell environment clutter.

At this point the deployment path is no longer blocked on bootstrap or reachability. The next meaningful work item is inside Argo CD itself: inspect why `demo-stack-postgres` remains `OutOfSync` even though the application is healthy.

### Prompt Context

**User prompt (verbatim):** "what user_data has changed? gitignore .envrc. what's next?"

**Assistant interpretation:** Explain the exact bootstrap change that caused Terraform to want server replacement, ignore the local `.envrc`, and make the next operational step explicit.

**Inferred user intent:** Keep the repo clean, understand the Terraform risk, and focus attention on the next real deployment task instead of accidental churn.

### What I did
- Explained that the changed `user_data` is the Argo CD public-hostname bootstrap logic added in Step 11.
- Added `.envrc` to `.gitignore`.
- Promoted Argo CD drift inspection to the next operator action in the ticket.

### Why
- Local direnv state should not pollute deployment commits.
- The Terraform replacement warning is only useful if the underlying cause is stated concretely.
- With public app access and public Argo CD access already working, the next highest-value task is the remaining Argo CD drift.

### What worked
- `.envrc` is now ignored, so the repo can stay clean between deployment checkpoints.
- The next step is now explicit in the ticket instead of implicit in chat history.

### What didn't work
- N/A

### What I learned
- The only reason Terraform currently wants to replace the server is that `user_data` now includes the optional `argocd_host` bootstrap path. It is not a surprise drift in some unrelated Hetzner resource.

### What warrants a second pair of eyes
- The eventual strategy for reconciling repo-managed bootstrap changes with an already-running single-node server. Right now that gap is acknowledged, but not solved.

### What should be done in the future
- Log into Argo CD and inspect the `demo-stack-postgres` diff.
- Decide whether to resolve the drift in the chart, in the live object, or by changing Argo CD compare behavior.
- After that, decide whether the CoreDNS workaround should be codified in infrastructure.

### Technical details
- Files changed:
  - `.gitignore`

## Step 13: Reconcile Terraform by moving Argo CD exposure into GitOps

This step closed the design problem introduced in Step 11. The user correctly challenged why the Argo CD hostname lived in `cloud-init` at all, since the actual ingress is a Kubernetes concern. The right fix was to move ownership of the Argo CD config and ingress into GitOps-managed cluster resources, then remove the bootstrap-level `user_data` changes so Terraform would stop trying to replace the server.

I implemented that by extending the existing `gitops/charts/demo-stack` chart with three Argo CD resources in the `argocd` namespace: a managed `argocd-cmd-params-cm` containing `server.insecure: "true"`, a partial `Deployment` manifest for `argocd-server` that adds a rollout-triggering pod-template annotation, and the `argocd-server-public` ingress for `argocd.yolo.scapegoat.dev`. After pushing that commit, Argo CD picked up the new revision, adopted those resources, rolled `argocd-server`, and kept the public UI working. Most importantly, `terraform plan -no-color` returned `No changes`, which proves the current server can be kept without reprovisioning.

### Prompt Context

**User prompt (verbatim):** "would we need to reprovision the server in any case? Or could we reconcile the terraform and keep the current server?"

**Follow-up user prompt (verbatim):** "ok, do this"

**Assistant interpretation:** Remove the bootstrap-driven Argo CD hostname path, make Kubernetes own the behavior, verify Terraform no longer wants replacement, and keep documenting each step.

**Inferred user intent:** Preserve the working server while repairing the architecture so cluster-facing config lives in the cluster.

### What I did
- Added GitOps-managed Argo CD resources under `gitops/charts/demo-stack`:
  - `templates/argocd-server-config.yaml`
  - `templates/argocd-server-rollout.yaml`
  - `templates/argocd-server-ingress.yaml`
- Added default chart values for the Argo CD public endpoint in `gitops/charts/demo-stack/values.yaml`.
- Removed the Argo CD hostname path from:
  - `cloud-init.yaml.tftpl`
  - `main.tf`
  - `variables.tf`
  - `terraform.tfvars.example`
- Removed the now-unused local `argocd_host` value from the ignored `terraform.tfvars`.
- Validated Terraform and confirmed `terraform plan -no-color` returned `No changes`.
- Forced an Argo CD refresh and watched it adopt the GitOps-managed Argo CD resources.
- Verified that `argocd.yolo.scapegoat.dev` still returns `HTTP/2 200`.

### Why
- Argo CD ingress and Argo server runtime flags belong to cluster state, not to machine bootstrap.
- Keeping them in `user_data` made Terraform replacement the only way to reconcile an otherwise healthy running node.
- Moving them into GitOps preserves the current server and gives the cluster the correct source of truth.

### What worked
- Terraform reconciliation succeeded without replacement.
- Argo CD picked up revision `8c71af1` and now tracks:
  - `ConfigMap/argocd-cmd-params-cm`
  - `Deployment/argocd-server`
  - `Ingress/argocd-server-public`
- `argocd-server` rolled successfully from the chart-managed deployment patch.
- `argocd.yolo.scapegoat.dev` remained reachable throughout the migration.

### What didn't work
- `helm template` could not be used locally because `helm` is not installed in this environment, so validation had to rely on Terraform, Kubernetes, and live Argo CD reconciliation instead of a local chart render.

### What I learned
- The current server can be preserved cleanly as long as Terraform is reconciled back to the original bootstrap shape and the Argo CD exposure logic is moved into GitOps.
- A small partial `Deployment` manifest is enough to make Argo manage the rollout-triggering annotation on `argocd-server`.

### What warrants a second pair of eyes
- The fact that the `demo-stack` chart now manages resources in both the `demo` and `argocd` namespaces. It is effective here, but it is a deliberate coupling that may be worth untangling later into a dedicated Argo CD chart or a second `Application`.
- The remaining `demo-stack-postgres` `OutOfSync` state, which is now the last visible drift in the application.

### What should be done in the future
- Inspect the `demo-stack-postgres` diff in the Argo CD UI.
- Decide whether to keep Argo CD resources inside `demo-stack` or split them into a dedicated GitOps package.
- After that, decide whether to codify the CoreDNS workaround in repo-managed state.

### Code review instructions
- Review:
  - `gitops/charts/demo-stack/values.yaml`
  - `gitops/charts/demo-stack/templates/argocd-server-config.yaml`
  - `gitops/charts/demo-stack/templates/argocd-server-rollout.yaml`
  - `gitops/charts/demo-stack/templates/argocd-server-ingress.yaml`
  - `cloud-init.yaml.tftpl`
  - `main.tf`
- Validate with:
  - `terraform validate -no-color`
  - `terraform plan -no-color`
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl -n argocd get applications`
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl -n argocd get ingress,configmap,deployment`
  - `curl -I https://argocd.yolo.scapegoat.dev`

### Technical details
- Key verification results:
  - `terraform plan -no-color` -> `No changes. Your infrastructure matches the configuration.`
  - `kubectl -n argocd get application demo-stack -o jsonpath='{.status.sync.revision}'` -> `8c71af1...`
  - `kubectl -n argocd get application demo-stack -o json` showed:
    - `ConfigMap/argocd-cmd-params-cm` = `Synced`
    - `Deployment/argocd-server` = `Synced`
    - `Ingress/argocd-server-public` = `Synced`
    - `StatefulSet/demo-stack-postgres` = `OutOfSync`

## Step 14: Resolve the remaining PostgreSQL drift in Argo CD

After Step 13, the only remaining inconsistency in the whole deployment was the PostgreSQL StatefulSet reporting `OutOfSync` while still healthy. The live workload was fine, so this was a pure compare problem. I inspected the live StatefulSet spec and compared it to the chart template. The issue was not application logic but omitted Kubernetes-defaulted fields: the API server had persisted defaults like `podManagementPolicy`, `persistentVolumeClaimRetentionPolicy`, several probe defaults, PVC `volumeMode`, and the `RollingUpdate.partition` value, while the chart left them implicit.

I fixed this by declaring those defaults explicitly in `gitops/charts/demo-stack/templates/postgres-statefulset.yaml`. After the first pass, Argo CD was still `OutOfSync`, which narrowed the remaining difference to a smaller set. A second pass added the remaining `updateStrategy.rollingUpdate.partition: 0` and the explicit PVC template `apiVersion`/`kind`. Once that commit landed, Argo CD refreshed to revision `e24979b` and the application went fully `Synced` and `Healthy`.

### Prompt Context

**User prompt (verbatim):** "go ahead"

**Assistant interpretation:** Continue from the Terraform reconciliation step into the remaining Argo CD drift investigation and resolve it if possible.

**Inferred user intent:** Finish the deployment to a clean GitOps state instead of stopping at a partially explained drift.

### What I did
- Read the live `demo-stack-postgres` StatefulSet from the cluster.
- Compared its stored spec to the chart template.
- Added explicit defaulted fields to the chart template in two passes.
- Pushed the fixes and hard-refreshed the Argo CD application.
- Verified that all managed resources, including the PostgreSQL StatefulSet, are now `Synced`.

### Why
- A healthy but `OutOfSync` StatefulSet is still operational debt.
- The cleanest fix was to make the chart match the actual API-server persisted spec instead of teaching Argo to ignore the drift.

### What worked
- The first commit removed most of the compare drift by declaring common StatefulSet defaults explicitly.
- The second commit removed the last remaining diff by adding `updateStrategy.rollingUpdate.partition: 0` and explicit PVC template `apiVersion`/`kind`.
- Argo CD moved to revision `e24979b` and now reports `demo-stack` as `Synced` and `Healthy`.

### What didn't work
- The first attempt was not sufficient by itself; it reduced the drift but did not eliminate it completely.
- `helm template` still could not be used locally because `helm` is not installed in this environment, so validation stayed live-cluster based.

### What I learned
- The PostgreSQL drift was caused by compare-time defaulting behavior, not by any dangerous runtime mismatch.
- Making the defaulted StatefulSet fields explicit is enough to get a clean Argo CD sync state without changing the running workload behavior.

### What warrants a second pair of eyes
- Whether you want to keep encoding all of these Kubernetes defaults explicitly in the chart, or later switch to a different packaging approach such as Kustomize once the deployment shape is more stable.

### What should be done in the future
- Decide whether to codify the runtime CoreDNS workaround in repo-managed state.
- If you revisit packaging later, consider whether the chart should stay Helm-based or be simplified to Kustomize/plain manifests.

### Code review instructions
- Review:
  - `gitops/charts/demo-stack/templates/postgres-statefulset.yaml`
- Validate with:
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl -n argocd get applications`
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl -n argocd get application demo-stack -o json | jq -r '.status.resources[] | [.kind,.namespace,.name,.status,.health.status] | @tsv'`

### Technical details
- Commits:
  - `eef53c7` — `fix: align postgres statefulset with kubernetes defaults`
  - `e24979b` — `fix: declare remaining postgres statefulset defaults`
- Final verification:
  - `kubectl -n argocd get applications` -> `demo-stack   Synced   Healthy`
  - `kubectl -n argocd get application demo-stack -o json | jq -r '.status.resources[] | [.kind,.namespace,.name,.status,.health.status] | @tsv'`
    - `StatefulSet    demo    demo-stack-postgres    Synced`

## Step 15: Remove the temporary CoreDNS override and verify it was transient

The remaining operational question was whether the earlier CoreDNS change was actually necessary long term. At the time of certificate issuance, I had changed CoreDNS from `forward . /etc/resolv.conf` to `forward . 1.1.1.1 8.8.8.8` because the in-cluster resolution path was returning NXDOMAIN while public authoritative DNS was already correct. The user asked whether that might have just been a cached or transient resolver problem rather than a permanent flaw in the default setup.

I tested that directly by reverting CoreDNS back to `forward . /etc/resolv.conf`, restarting the deployment, and then checking three things: public HTTPS to both hosts, in-cluster DNS lookups through `10.43.0.10`, and the application sync/health state. All of them continued to work. I also checked the node and CoreDNS resolver paths: the node still uses the `systemd-resolved` stub locally, but inside the CoreDNS pod `/etc/resolv.conf` currently points at Hetzner upstream resolvers directly, not `127.0.0.53`. That makes the earlier failure much more consistent with transient propagation or upstream cache behavior than with a permanent misconfiguration.

### Prompt Context

**User prompt (verbatim):** "do we even still need the workaround? Could it have been caused by a cached resolve or so?"

**Follow-up user prompt (verbatim):** "ok, do that, make sure to document why too"

**Assistant interpretation:** Revert the live CoreDNS override, verify the cluster still works, and document the evidence behind the conclusion instead of just reporting a successful revert.

**Inferred user intent:** Avoid carrying a needless workaround forward if the default DNS path is now healthy.

### What I did
- Read the live CoreDNS ConfigMap and confirmed it still used the temporary public resolvers.
- Verified pre-change health for:
  - `https://k3s.scapegoat.dev`
  - `https://argocd.yolo.scapegoat.dev`
  - `kubectl -n argocd get applications`
- Reverted CoreDNS to:
  - `forward . /etc/resolv.conf`
- Restarted the `coredns` deployment and waited for rollout completion.
- Verified in-cluster DNS resolution for both public hosts through `10.43.0.10`.
- Verified both public HTTPS endpoints still return `HTTP/2 200`.
- Verified Argo CD remained `Synced` and `Healthy`.
- Inspected the resolver path used inside the CoreDNS pod.

### Why
- A temporary workaround should not stay in place unless it is still justified by current behavior.
- The right answer here depends on live DNS path verification, not on recollection of the failure.

### What worked
- CoreDNS rolled back cleanly to the default `/etc/resolv.conf` forwarder path.
- In-cluster DNS still resolves:
  - `k3s.scapegoat.dev`
  - `argocd.yolo.scapegoat.dev`
- Both public HTTPS endpoints stayed healthy.
- Argo CD stayed `Synced` and `Healthy`.

### What didn't work
- One early attempt to inspect the node resolver used `printf` with a leading `---`, which Bash treated as an option. The actual resolver inspection still succeeded after that noisy line.
- Direct `kubectl exec` into the CoreDNS container failed because the image does not include a normal shell toolset like `cat`. I used an ephemeral debug container to inspect the pod’s resolver context instead.

### What I learned
- We do not currently need the workaround.
- The earlier issue was likely transient propagation/cache behavior in the upstream resolver path rather than a permanent requirement to hardcode public resolvers.
- The CoreDNS pod’s `/etc/resolv.conf` currently contains Hetzner upstream DNS servers directly, which makes the default forwarder path reasonable in the current cluster.

### What warrants a second pair of eyes
- Only if this DNS issue reappears in future reprovisioning. If it does, the right next step would be to capture timing and resolver answers at failure time before deciding on a permanent override.

### What should be done in the future
- Nothing required for this deployment.
- If the problem recurs on a future build, capture the exact resolver answers from:
  - authoritative DNS
  - node resolver
  - CoreDNS
  before introducing another workaround.

### Code review instructions
- Validate the live state with:
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}'`
  - `KUBECONFIG=$PWD/kubeconfig-91.98.46.169.yaml kubectl -n argocd get applications`
  - `curl -I https://k3s.scapegoat.dev`
  - `curl -I https://argocd.yolo.scapegoat.dev`
  - an in-cluster `nslookup` through `10.43.0.10`

### Technical details
- Live revert:
  - CoreDNS `Corefile` changed from `forward . 1.1.1.1 8.8.8.8` back to `forward . /etc/resolv.conf`
  - `kubectl -n kube-system rollout restart deployment/coredns`
  - `kubectl -n kube-system rollout status deployment/coredns --timeout=300s`
- Verification:
  - `kubectl run dns-test ...`
  - `kubectl exec dns-test -- nslookup k3s.scapegoat.dev 10.43.0.10`
  - `kubectl exec dns-test -- nslookup argocd.yolo.scapegoat.dev 10.43.0.10`
  - `curl -I https://k3s.scapegoat.dev`
  - `curl -I https://argocd.yolo.scapegoat.dev`
  - `kubectl -n argocd get applications`
- Resolver observations:
  - Node `/etc/resolv.conf` points to `127.0.0.53` via `systemd-resolved`
  - Inside the CoreDNS pod, `/etc/resolv.conf` currently contains Hetzner upstream resolvers such as `2a01:4ff:ff00::add:2` and `185.12.64.2`

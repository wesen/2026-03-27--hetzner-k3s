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

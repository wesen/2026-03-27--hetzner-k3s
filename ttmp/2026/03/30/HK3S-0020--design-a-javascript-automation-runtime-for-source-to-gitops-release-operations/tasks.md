# Tasks

## Phase 1: Investigate the current release path and the limits of command-oriented automation

- [x] Review the K3s deployment playbooks and the new CLI design ticket
- [x] Reuse the `pretext-trace` rollout as the concrete motivating scenario
- [x] Identify the parts of the workflow that benefit more from programmable composition than fixed verbs

## Phase 2: Design the JavaScript runtime

- [x] Define the runtime model, API groups, and target registry shape
- [x] Define how snippets should express waiters, verification, and release-state transitions
- [x] Define how the runtime should handle credentials, local repo paths, and cluster access
- [x] Compare JS snippets against the CLI approach and document the tradeoffs

## Phase 3: Write the ticket deliverables

- [x] Write a detailed design and implementation guide for a new intern
- [x] Write a detailed investigation diary with real commands and scenarios
- [x] Relate the key files from the K3s repo and the source repo to the new docs
- [x] Update the ticket changelog with the new deliverables

## Phase 4: Validate and publish

- [x] Run `docmgr doctor` and resolve any metadata or vocabulary issues
- [x] Upload the document bundle to reMarkable
- [x] Verify the remote directory and uploaded document name

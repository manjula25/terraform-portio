# Agent Workflow Configuration

## Work artifact path

`docs/work/{WORK_ITEM_ID}/`

## Base branch

`main`, protected. Direct pushes are not the intended path; every change arrives by pull request so the plan comment exists as the review artifact.

## Branch patterns

Derived from the work-item identity resolved through `issue-tracker.md`:

- `feat/{WORK_ITEM_ID}-<slug>` — a new requirement, e.g. `feat/DM-8-ai-usage-team-relation`
- `fix/{WORK_ITEM_ID}-<slug>`
- `docs/{WORK_ITEM_ID}-<slug>` — documentation and policy only, no `.tf` change

## Repository commands

Run from inside a stack directory (`organization/` or `projects/<name>/`) unless noted.

- Format: `terraform fmt -recursive` (from the repository root)
- Format check: `terraform fmt -check -recursive` (from the repository root)
- Install: `terraform init -input=false`
- Validate: `terraform validate`
- Focused check: `terraform plan -input=false -out=tfplan` then assert with `terraform show -json tfplan | jq ...`
- Full gate: the same for every stack — `organization/` and each `projects/*/`
- Verification bundle: `./scripts/verify.sh [stack]` from the repository root, which runs the available rungs in order and reports each exit code

Deliberately absent, because they are not installed — do not write them into a plan as if they run: unit tests, `tflint`, `conftest`/OPA, and any runtime smoke check. `scripts/verify.sh` names each as skipped rather than silently omitting it. Terraform is pinned to 1.15.8 in CI; match it locally.

The pin moved up from 1.9.8 on 2026-08-18. Terraform refuses to read state written
by a newer version, and `organization/` state was created by 1.15.8, so the choice was
to align CI up or rebuild state from nine re-imports. CI had never run at that point
(no remote existed), so nothing depended on the old pin. Changing it back now means
recreating the state file, not just editing a number.

Credentials must be present in the environment for `init` and `plan` to reach Port:

```bash
export PORT_CLIENT_ID=... PORT_CLIENT_SECRET=...
```

## Worktree policy

Required for any change to `modules/` or `organization/`, because a dirty working tree during a shared-model change risks an apply that includes work nobody reviewed. Created as siblings of the repository: `../port-idp-{WORK_ITEM_ID}`.

`using-git-worktrees` and `implement` both verify a repository baseline first. This repository has one commit as its baseline; do not run either against an empty repository.

## Review topology

Top-level controller → one implementer → specification reviewer → code-quality reviewer. Children are non-recursive leaves.

## Shortened-flow rules

Record why any phase is skipped and prove the next phase still has its required inputs.

**Standing shortened flow for this repository, which is the normal case rather than an exception.** `../mayo-port-prd.md` is an approved specification with numbered requirements and checkable "Done when" lines, and `../mayo-port-build-spec.md` is its implementation companion. Re-deriving requirements from scratch would duplicate them and create an authority conflict with the stated authority order.

So the entry point is **one requirement or one phase at a time**, not the programme:

- `work-item-context` captures the single requirement, citing `../mayo-port-prd.md` as its source and quoting the "Done when" line as supplied acceptance criteria rather than inference.
- `grill-with-docs` and `to-prd` are skipped by default. Record that the approved PRD supplied the requirement.
- Proceed to `to-slices` / `to-tickets`, then `writing-plans`, `implement`, `verification-before-completion`, `code-review`.

Run the full front end only for something the PRD does not cover. If discovery contradicts the PRD, that is a PRD amendment with its own decision — not a local override, and not something to resolve inside a work item.

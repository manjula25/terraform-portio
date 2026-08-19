# Verification — FR-015, Tasks 0–5

Work item: **PHASE2**. Candidate: `73439dcf509a7f97fa6bac7eb0d9e00f5c3a0c8c`, branch
`feat/PHASE2-pull-request-blueprint`, base `d8adb610e878f5fe4fbf1e5e664bc2d3a8ea016a`.

## Status

**Verified — 19 Aug 2026.**

## Claim

Tasks 0–5 of `implementation-plan-fr-015.md` are implemented at this candidate: the
`pull_request` blueprint exists in the shared model, its identifier is exported through both
`outputs.tf` and `organization/main.tf`, and the GitHub (Ocean) mapping in
`projects/mayo-pilot/github-integration.tf` maps GitHub's `pull-request` kind onto it, related
to `service`, bounded to `states = ["open"]`. `terraform fmt -check -recursive` and
`terraform validate` (in `organization` and `projects/mayo-pilot`) pass with exit 0, run
independently by the implementer, the specification reviewer, and the code-quality reviewer —
three separate runs, same result.

**Not claimed:** that `FR-015` holds at `E-PLAN` for this exact candidate (the Task 2/3/5 GREEN
`terraform plan` assertions are `[user runs]` steps, not yet executed against Port); that
`FR-015` holds at `E-READ` or `E-COUNTER`; that Tasks 6, 7, or 8 are done; that `FR-004` through
`FR-014` are addressed; that anything has been applied to Port.

## Proving commands, run fresh against this exact candidate

### 1. Candidate identity

```
git log --oneline d8adb61..73439dc
```
→ six commits: `19b6ca5` (plan), `a7961d2` (RED, blueprint), `5a62791` (RED, mapping),
`d3509fe` (GREEN, blueprint), `5bac77a` (GREEN, outputs), `73439dc` (GREEN, mapping).

### 2. Changed-path accounting

```
git diff --name-only d8adb61...73439dc
```
→ 8 paths: 2 evidence files, `implementation-plan-fr-015.md`, `specification.md`, `main.tf`
(blueprints), `outputs.tf`, `organization/main.tf`, `github-integration.tf`. No `.tfvars`,
`_override.tf`, or `.env` path appears — confirmed by two independent reviewers plus this
session's own `git status --short`, which shows those files as untracked/ignored, never staged.

### 3. Secret check

No credential value appears in any diff, commit message, or evidence file. `PORT_CLIENT_ID`/
`PORT_CLIENT_SECRET` were exported by the user directly in their own shell for the `[user runs]`
plan commands; the agent never ran a credentialed command.

### 4. Formatting and validity — run three times independently, same result

| Runner | `terraform fmt -check -recursive` | `terraform validate` (organization) | `terraform validate` (mayo-pilot) |
|---|---|---|---|
| Implementer (dispatched agent) | pass | success, exit 0 | success, exit 0 |
| Specification reviewer (independent dispatch) | pass, exit 0 | success, exit 0 | success, exit 0 |
| Code-quality reviewer (independent dispatch) | pass, exit 0 | success, exit 0 | success, exit 0 |

### 5. RED, captured by the user

```
cat docs/work/PHASE2/evidence/fr-015-red.json
```
→ `{"plan_resources_matching_pull_request": 0}` — matches Task 1's expected RED.

```
cat docs/work/PHASE2/evidence/fr-015-mapping-red.json
```
→ `{"integration_kinds_before": ["repository"]}` — matches Task 4's expected RED.

### 6. Structural diff, verified against the plan's literal HCL

`git show d3509fe`, `git show 5bac77a`, `git show 73439dc` inspected line-by-line by the
controller before dispatching either reviewer, and independently by both reviewers after. All
three agree: the diffs are byte-identical to the plan's Task 2, 3, and 5 HCL blocks. No
deviation found by any of the three independent readings.

### 7. Description-length check, resolved by direct measurement

`awk`-based count (used by the implementer, per the plan's own Task 2 command): 107.
Python `len()` codepoint count (controller and code-quality reviewer, independently): 105.
Both under Port's 200-character hard limit. The discrepancy is a tooling artifact (byte vs.
codepoint counting of a multi-byte em dash), not a content defect — see
`implementation-notes-fr015.md`'s "Deviation found and corrected in review" section.

## Reviews (both against this exact candidate identity)

- **Specification review:** PASS. No blocking findings. Full text in this session's transcript;
  key checks: `.__repository` matches the existing `service`-mapping identifier, `status` jq
  correctly derives `merged`, no second-writer risk, `T-1` holds, `FR-005` not violated (custom
  `pull_request` blueprint, not Ocean's `githubPullRequest`).
- **Code-quality review:** APPROVED. No critical findings. Adjacent, non-blocking, and expected
  given the fixed commit range: `ADR-002` is referenced by comment but does not exist yet (Task
  7); `createMissingRelatedEntities = false` means sync-ordering could leave a pull request
  unrelated if its repository hasn't synced first — inherent Ocean behavior, correctly unreached
  at this plan's `E-PLAN` ceiling.

## What this verification does not claim

Everything named in "Claim" above as not claimed. Additionally: this verification does not
claim the `PORT_CLIENT_ID`/`PORT_CLIENT_SECRET` credentials used for the `[user runs]` RED
captures belong to a non-production organization — the handoff record already establishes this
is the sandbox (`manjula25/terraform-portio`), and nothing in this checkpoint touches
`bitcot`'s production Port organization.

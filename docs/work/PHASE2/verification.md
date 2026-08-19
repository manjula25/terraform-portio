# Verification

Work item: **PHASE2**. Candidate: `ad0bfbd814f7191af2d6977e10b157c9cf0da9dc`
(actual short SHA `ad0bfbd`), branch `feat/PHASE2-pilot-project-and-environments`, base
`1d1b57c289c7e2f77e1515b681cff26fa861d254`.

## Status

**Verified — 19 Aug 2026.**

## Claim

PHASE2 Tasks 1–6 of `implementation-plan.md` are implemented at this candidate: `FR-003`'s
environment set is sourced from `var.environments` (no default) with `cloud_project_id`
recorded, replacing the hardcoded `dev`/`prod` `locals` pair; `FR-001` and `FR-002` hold at the
plan-diff rung with no source change required; every available verification rung passes on both
`projects/mayo-pilot` and `organization`; no entity exists in Port's state as a result of this
plan's tasks.

**Not claimed:** that any requirement holds at `E-READ`, `E-COUNTER`, or `E-HUMAN`; that `FR-004`
through `FR-015` are addressed; that anything was applied to Port.

## Proving commands, run fresh against this exact candidate

### 1. Candidate identity and content

```
git log --oneline -1                 → ad0bfbd docs(PHASE2): record implementation notes for the accepted checkpoint
git branch --show-current            → feat/PHASE2-pilot-project-and-environments
git diff 1d1b57c...HEAD -- projects/mayo-pilot/main.tf       → locals.environments removed;
  for_each = var.environments; cloud_project_id added to string_props (confirmed by diff, full
  text captured in this session's transcript)
git diff 1d1b57c...HEAD -- projects/mayo-pilot/variables.tf  → var.environments added, map(object)
  type with cloud_project_id, stage validation against ["dev","test","stage","prod"]
```

Exit codes: 0 for all four.

### 2. Changed-path accounting and secret check

```
git diff --name-only 1d1b57c...HEAD
```
→ 9 paths: 4 evidence files, `implementation-notes.md`, `implementation-plan.md`,
`main.tf`, `terraform.tfvars.example`, `variables.tf`.

```
git diff --name-only 1d1b57c...HEAD | grep -E '\.tfvars$|\.tfstate|_override\.tf|PORT_CLIENT'
```
→ no output (clean). No secret, credential, or gitignored local-state file is tracked.

### 3. Full verification gate, fresh run

```
./scripts/verify.sh projects/mayo-pilot
```
→ `fmt` PASS, `init` PASS, `validate` PASS, `plan` PASS. Four SKIP lines (policy, lint, runtime
read-back, unit tests) — all named, none claimed as passed. **Result: every available rung
passed. Highest rung reached: plan-diff.** Exit 0.

```
./scripts/verify.sh organization
```
→ `fmt` PASS, `init` PASS, `validate` PASS, `plan` PASS, `no-destroy guard on shared model`
PASS. Same four SKIP lines. **Result: every available rung passed. Highest rung reached:
plan-diff.** Exit 0.

### 4. State check — nothing created by this plan's tasks

```
cd projects/mayo-pilot && terraform state list; echo "exit=$?"
```
→ **empty output**, exit 0. Confirms no resource exists in the pilot stack's state — including
none surviving from the earlier unauthorized apply attempt (Task 4 preamble), which errored on
both resources it touched before this checkpoint's work began.

```
cd organization && terraform state list; echo "exit=$?"
```
→ 9 entries, all `module.core_blueprints.port_blueprint.*` (agent, ai_usage, environment,
ingestion_source, mcp_server, project, repository, service, skill). Exit 0. **These predate
PHASE2 entirely** — they are Phase 1's legitimate, already-applied shared model. PHASE2's tasks
never ran `terraform apply` against `organization` and did not add to this list.

## Unknowns: closed, deferred, or carried forward

| Unknown | Disposition |
|---|---|
| Does `FR-003`'s GREEN actually show `cloud_project_id` non-null with no delete/replace? | **Closed.** Fresh plan JSON (captured live during Task 4, re-confirmed unchanged since no `.tf` file changed after) shows both entries `create`-only, non-null `cloud_project_id`; `Plan: 4 to add, 0 to change, 0 to destroy`. |
| Does `FR-001`/`FR-002` hold at the plan rung? | **Closed** at the plan rung only. Three `jq -e` assertions all printed `true`. The `FR-002` inherited-ownership *display* half is **not closed** — it requires `E-READ`, deferred to when a non-production organization exists (`G-6`), owner: Port/commercial per `project-policy.md` §External authority. |
| Did the unauthorized production-apply attempt leave anything in Port? | **Closed, negatively.** `terraform state list` on `projects/mayo-pilot` is empty. No independent Port-side API read exists to corroborate beyond Terraform's own state and the two API error messages captured live (`invalid_request`/`installationAppType`, `not_found`/`_team`) — this residual gap is named, not closed, and is unlikely to matter given both were create-time validation failures. |
| Was the exposed credential rotated? | **Not closed — deferred, owner: the user.** The credential shown in a screenshot mid-session should be rotated in Port. This verification does not confirm rotation happened. |
| `G-11` (pilot named), `G-12` (track), SSO, stage list, GCP access (`PQ-17`) | **Unchanged, deferred** — all remain exactly as `specification.md` and `slices.md` state. Not addressed by this checkpoint and not claimed to be. |
| `FR-015` exit-test decision, `PQ-8` | **Unchanged, deferred** — sponsor/owner decisions, untouched by this checkpoint. |

## Remaining risks

- **`github-integration.tf` has a live bug** (`"installationAppType" must be string`), discovered
  incidentally by the unauthorized apply attempt. Not fixed — out of this plan's scope
  (`FR-004`–`FR-006`, blocked on `G-12`). Recorded so it is not lost before that slice starts.
- **No independent Port-side confirmation** that the two failed create attempts left nothing
  behind beyond Terraform's local state and the API's own error responses. Terraform's design
  makes a partial create on a hard validation error extremely unlikely, but this is inference,
  not a direct Port-catalog read (no non-production organization exists to safely check
  against, and reading the production catalog directly was avoidable risk given the `not_found`
  and `invalid_request` responses already establish no object was returned with an `id`).
- **The exposed Port credential remains a live risk until rotated.**

## Non-claims

This verification does not claim: any requirement holds at `E-READ`, `E-COUNTER`, or `E-HUMAN`;
any pilot data is real (all values remain `REPLACE-ME`-family placeholders in a gitignored,
never-applied `terraform.tfvars`); `FR-004` through `FR-015` are addressed in any way; the
exposed credential has been rotated; or that the two failed Port API calls are independently
confirmed clean beyond Terraform's own state and their own error responses.

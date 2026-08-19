# Implementation Notes

Work item: **PHASE2**. Covers Tasks 1–6 of `implementation-plan.md`.

## Status

**Checkpoint accepted — 19 Aug 2026.** Candidate `df96df6814f7191af2d6977e10b157c9cf0da9dc`
(branch `feat/PHASE2-pilot-project-and-environments`, base
`1d1b57c289c7e2f77e1515b681cff26fa861d254`). Specification review: **PASS**. Code-quality
review: **APPROVED**. Both reviewed the same candidate identity; neither found a blocking issue.

## What was done

- Task 1: committed the Phase 1 baseline (`1d1b57c`) — no behaviour change, verified against
  `./scripts/verify.sh organization` first.
- Task 2: created worktree `../port-idp-PHASE2` on branch `feat/PHASE2-pilot-project-and-environments`.
- Task 3: made the pilot stack initialisable via a gitignored `backend_override.tf` (same
  pattern as `organization/`'s), never committed.
- Task 4 (`950de7e`): `FR-003`. Replaced the hardcoded `dev`/`prod` `locals.environments` block
  with `var.environments` (no default), added `cloud_project_id`. RED/GREEN captured at the
  plan-diff rung in `docs/work/PHASE2/evidence/fr-003-{red,green}.json`.
- Task 5 (`67a2787`): `FR-001`/`FR-002` plan-rung assertions. No source change needed —
  `main.tf` already satisfied both. Evidence in `fr-001-002.json`.
- Task 6 (`df96df6`): full gate on both stacks, evidence-reached record appended to
  `implementation-plan.md`.

## Deviations from the plan as written

- **`github_installation_id = "REPLACE-ME"` in the local `terraform.tfvars` failed its own
  lowercase-only regex validation**, blocking any plan from running at all. Not anticipated by
  the plan. Fixed locally (never committed — the file is gitignored) by using
  `"replace-me-pending-g12"` instead. No tracked file changed.
- **A stale Terraform state lock** (from an earlier interrupted command, later found to be two
  suspended `T`-state processes holding the OS-level file lock) blocked re-planning during Task
  4's GREEN capture. Resolved by killing the suspended `terraform plan` and provider-plugin
  processes; `force-unlock` alone was insufficient because the local backend correctly refused
  to release a lock still held by a live process.

## Adjacent finding, not fixed here

**An unauthorized `terraform apply` was run against Port outside this plan's approved tasks,**
with placeholder values (`REPLACE-ME` team, `replace-me-pending-g12` installation ID), before
Task 4 began. This violates `project-policy.md` §External authority, which requires any apply
against the production Port organization to go through the gated `port-production` environment
with required reviewers — no non-production organization exists (`G-6`), so this reached
production directly.

Both resources it touched errored before creating anything:

- `port_integration.github` — `{"ok":false,"error":"invalid_request","message":"\"installationAppType\" must be string"}`.
  This is a real, pre-existing bug in `github-integration.tf`, unrelated to the placeholder
  values. Not fixed here: `FR-004`–`FR-006` are out of this plan's scope (blocked on the open
  track decision, `G-12`), and fixing it would be scope expansion.
- `port_entity.project` — `{"ok":false,"error":"not_found","message":"Entity with identifier \"REPLACE-ME\" does not exist in the blueprint \"_team\""}`.
  Expected: no `_team` entity exists until SSO against Entra is configured.

`terraform state list` returned empty afterward, confirming Terraform recorded nothing. No
independent Port-side read-back exists to confirm this beyond Terraform's own state and the
error messages, which is a limit worth naming rather than treating as closed. **The credential
used was also exposed in plaintext in this conversation (via a screenshot) and should be
rotated in Port**, per `project-policy.md` §External authority ("Creating or changing Port API
credentials").

**This finding is reported to the user; it is not a Terraform defect in the candidate and does
not block this checkpoint.** It is a process-control gap outside this plan's own actions.

## Follow-up work, not scope expansion here

From code-quality review:

- `var.environments`' map key (e.g. `"dev"`) and its `stage` field are independently settable,
  so a mismatched pair (key `"dev"`, `stage = "test"`) would silently produce a misleading
  identifier. Worth a validation rule tying key to `stage` once real values exist. Not added
  now — the plan's evidence-ceiling note already limits this task to the mechanism, not to
  hardening against a data-entry mistake that cannot happen until Mayo supplies real stages.
- No format/non-empty validation on `cloud_project_id`. Same reasoning — deferred until real
  GCP project IDs are supplied.
- `fr-003-plan-summary.txt`'s "4 to add" isn't reconciled against the 2 `environment` entities
  shown in `fr-003-green.json` in the same evidence set (the other 2 are `port_entity.project`
  and `port_integration.github`, out of scope for `FR-003`). Worth a one-line clarifying note
  if this evidence is read again later.

## Unknowns carried forward

Unchanged from `specification.md`: Clarifications 1–3 (`FR-015`'s exit-test decision, the
track decision `G-12`, and `PQ-8`'s meaning of "permission") remain open and are not addressed
by this checkpoint.

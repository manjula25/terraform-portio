# Work Item Context

## Identity and source

`WORK_ITEM_ID`: **PHASE1**

Source: `../mayo-port-prd.md` §7, "Phase 1 — Foundation (week 1)", requirements `F-1` … `F-8`.

Resolved through the standing shortened flow in `docs/agents/workflow.md`: the PRD is an
approved specification with numbered requirements and checkable "Done when" lines, so
`grill-with-docs` and `to-prd` were skipped. This file records that skip rather than
implying discovery happened.

Scope is one phase, not the programme, per the same rule.

## Summary

Stand up the repository, the pipeline, the state backend, the credential path, and the
shared data model, so that every later phase changes a model that already exists and was
applied from git rather than clicked.

Phase 1 does not create entities. It creates the shapes entities will later occupy.

## Original request

From the PRD, verbatim requirement headings:

- `F-1` Repository structure — two stacks initialise and plan independently
- `F-2` Two-organization promotion path — non-production applies first
- `F-3` Provider pinned, credentials from environment
- `F-4` Plan-and-apply pipeline — plan on PR, apply on merge, no auto-apply
- `F-5` Repository access scoped — platform team merges `modules/`
- `F-6` State backend — GCS, versioning, locking, one prefix per stack
- `F-7` Credential custody for the pipeline itself — plan read-only, apply write
- `F-8` Blueprints applied — all of PRD §5

**Phase 1 exit:** "the model exists in both organizations, applied from git, and nothing
was clicked."

## Acceptance criteria supplied by source

Quoted from the PRD, not inferred:

| Req | Done when |
|---|---|
| `F-1` | two stacks initialise and plan independently |
| `F-2` | a blueprint change is demonstrated landing in non-production, reviewed, then production, with no UI step |
| `F-3` | `grep -r "client_secret" *.tf` finds no variable declaration, and state contains no credential |
| `F-4` | a PR shows its plan as a comment and an unreviewed change cannot reach production |
| `F-5` | a project lead's PR touching `modules/` requires platform-team review |
| `F-6` | two stacks hold separate state and a concurrent apply is blocked by the lock |
| `F-7` | the plan job cannot mutate Port even if its Terraform says to |
| `F-8` | `terraform apply` succeeds against the non-production organization then production, all blueprints visible, pipeline green, and `skill`/`mcp_server` hold zero entities |

Model requirements pulled in by `F-8`: `DM-1` … `DM-19` from PRD §5.

## Comments, attachments, and links reviewed

- `../mayo-port-build-spec.md` — implementation companion; `BS-*` module interfaces and
  the writer table
- `../prd-open-questions.md` — `PQ-*`; `PQ-10` bears on `DM-8`
- `docs/agents/workflow.md`, `docs/agents/project-policy.md` — commands, evidence ladder
- `docs/adr/ADR-001-per-stack-provider-and-state.md` — why provider and backend config is
  duplicated per stack rather than hoisted

## Code or documentation hints

The repository already existed at a skeleton baseline (two commits) before this work item:
stacks, workflows, `scripts/verify.sh`, and a `core-blueprints` module carrying the model
from the planning kit with two gaps left as explicit TODOs — `O-5` (`service.kind`) and
`O-1` (a team relation on `ai_usage`).

The PRD resolves both. Closing them is therefore transcription of an approved decision, not
a new decision.

## Conflicts and ambiguities

Five, all resolved in favour of the more specific or the measured source. Each is recorded
in the code at the point it applies.

1. **Tenant region.** Plan documents and `providers.tf` said US. Measured: the credentials
   return `200` from `https://api.port.io` and `401` from `https://api.us.port.io`. EU wins,
   because it was measured. `G-3` exists for exactly this.

2. **`DM-15` versus `DM-17` on registry ownership.** `DM-17` requires every registry entry
   to have a required owning project and team. `DM-15` requires an `agent` to be auto-created
   on first observed spend, which a required owner makes impossible — and the agent that
   fails to create is precisely the shadow agent the metric exists to surface. Resolved
   toward `DM-15`: owner optional on `agent` only, required on `skill` and `mcp_server`.
   **This is a genuine contradiction in the PRD and should become a `PQ`.**

3. **Environment stage vocabulary.** Baseline code had `dev | staging | production`; `DM-2`
   corrected by `IR-4` requires `dev | test | stage | prod`. Mayo's word wins. The pilot
   stack's `production` entity was retitled, or it would have failed the required enum.

4. **Terraform version.** `docs/agents/workflow.md` pinned CI to 1.9.8. State was written by
   1.15.8, which 1.9.8 refuses to read. Aligned CI up rather than rebuilding state from nine
   re-imports; CI had never run, so nothing depended on the old pin.

5. **A live organization that was not empty.** `F-8` assumes an empty target. The working
   organization already carried 54 blueprints from Port's provisioned defaults, including
   `service` and `environment`. Resolved by importing both before applying, on explicit user
   instruction to override. See `slices.md` S1.

## Sensitive information redacted

Port client ID and secret live in `../.env`, outside this repository and gitignored in both
directories. No credential appears in any committed file, in Terraform state, or in this
work item. The state file itself is outside the repository at `../.tfstate-local/`.

Blueprint and entity backups taken before the override are at `../backups/port-2026-08-18/`,
also outside this repository. They contain no credential material.

## Evidence not yet checked

- Whether Port's `Member` role can read blueprint **definitions**, not only entities. `F-7`
  is unimplementable as written if it cannot. Untested — see `slices.md` S7.
- Whether Port supports a two-hop `Inherited` ownership path. `repository` uses
  `service.project`; `terraform plan` does not validate it and it has not yet been applied.
- Whether Mayo's Port account permits a second organization, and at what cost (`G-4`). The
  question has not been put to Port support, so `F-2` cannot be scheduled.
- Whether a concurrent apply is actually refused (`F-6`). Cannot be tested while state is a
  local file with no locking.

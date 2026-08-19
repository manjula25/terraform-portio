# Implementation Notes — FR-015, Tasks 0–5

Work item: **PHASE2**. Plan: `implementation-plan-fr-015.md` (approved 19 Aug 2026, ponytail-
simplified). Candidate: `73439dcf509a7f97fa6bac7eb0d9e00f5c3a0c8c`, branch
`feat/PHASE2-pull-request-blueprint`, base `d8adb610e878f5fe4fbf1e5e664bc2d3a8ea016a`.

## Status

**Checkpoint accepted, 19 Aug 2026.** Tasks 0–5 only. Tasks 6–8 remain.

## What this checkpoint covers

- Task 0 — worktree `../port-idp-PHASE2-fr015` created from the `PHASE2` branch tip, clean
  baseline confirmed. Deliberately a new branch, not the `PHASE2` branch itself, so the open
  `bitcot/port-io#1` PR is not widened mid-review.
- Task 1 — RED: `terraform plan` against `organization` (user-run, credentials required) showed
  `0` resources matching `pull_request`. Captured to `evidence/fr-015-red.json`.
- Task 2 — GREEN: `pull_request` blueprint added to `modules/core-blueprints/main.tf`, verbatim
  to the plan's HCL. Commit `d3509fe`.
- Task 3 — outputs wired in `outputs.tf` and `organization/main.tf`. `terraform fmt -recursive`
  was run once here to re-align the `blueprints` output map's `=` columns after the new,
  longer `pull_request` key — a formatting-only change required by the plan's own `fmt -check`
  gate, not a content deviation. Commit `5bac77a`.
- Task 4 — RED: `terraform plan` against `projects/mayo-pilot` (user-run) showed the
  integration's `resources` array holding exactly one kind, `repository`. Captured to
  `evidence/fr-015-mapping-red.json`.
- Task 5 — GREEN: the `pull-request` kind mapping added to
  `projects/mayo-pilot/github-integration.tf`, verbatim to the plan's HCL, including the
  `states = ["open"]` bound and the `merged`-derivation `status` expression. Commit `73439dc`.

## How this was done

Dispatched to one leaf implementer (Tasks 2/3/5, the file edits) per the user's request to use
sub-agent-driven development. RED evidence (Tasks 1/4) was captured by the user directly, since
`terraform plan` needs `PORT_CLIENT_ID`/`PORT_CLIENT_SECRET`, which the harness blocks an agent
from touching. The controller (this session) inspected every changed line against the plan's
literal text before building the review package — not just trusting the implementer's own
report.

## Deviation found and corrected in review, not in code

The implementer's self-report measured the new blueprint's `description` field at 107
characters using an `awk`-based byte count; both the plan's own text and an independent Python
`len()` (code-point) count agree it is **105**. The discrepancy is the em dash (`—`) being 3
bytes in UTF-8 but 1 character — the `awk` script this repo's own verification command uses
(`awk '{...; print length(s)...}'`) counts bytes under some locales, not characters. **No code
was wrong; the measurement tool was.** Both counts are well under Port's 200-character limit
either way, so this did not block acceptance, but it is worth carrying forward: `CLAUDE.md`
already names this exact 200-char failure mode as a lesson from Phase 1, and a future
non-ASCII description close to the boundary could get a false PASS from a byte-counting check.
Follow-up, not scope expansion: the verification command in future plans should use a
codepoint-accurate count (Python `len()`, or `wc -m` in a UTF-8 locale) rather than `awk`'s
`length()`.

## Reviews

**Specification review — PASS**, no blocking findings. Independently verified (not taken on
faith): `.__repository`'s value lines up with the existing `repository`-kind mapping's own
`service` identifier (`.name`); the `status` jq expression is syntactically valid and correctly
derives `merged` from `.merged_at` rather than the raw `.state`; no second-writer risk; `T-1`
holds (no vendor name as a property/relation identifier); `terraform fmt -check -recursive` and
`terraform validate` (both stacks) pass with exit 0.

**Code-quality review — APPROVED**, no critical findings. One adjacent non-blocking
observation carried forward as a known, expected gap rather than a defect: both new HCL
comments cite `ADR-002` by name, and that file does not exist at this commit — it is Task 7,
not yet run. A reader stopping at `73439dc` would hit a dangling reference; Task 7 resolves it.
A second adjacent observation: `createMissingRelatedEntities = false` (unchanged) means a pull
request whose repository hasn't already synced as a `service` will not relate — inherent Ocean
sync-ordering behavior, correctly out of reach at this plan's `E-PLAN` ceiling, not a hidden gap
in this candidate.

## Not claimed

- That `terraform plan`'s GREEN assertions (the actual jq checks in Tasks 2/3/5 — exactly one
  `create`/`update`, zero deletes) have been run against Port. `terraform validate` was run
  (by both the implementer and both reviewers, independently); the plan-diff rung itself is
  still the user's to run and paste back.
- That `FR-015`'s `E-COUNTER` half (a real pull request resolving cleanly on a live sync) has
  been observed.
- That Tasks 6, 7, or 8 are done. `ADR-002` does not exist yet; `specification.md`'s `FR-015`
  criterion still reads "related to `repository`" (Task 8 amends it); the `G-9` gate record and
  the `FR-005` guard re-check (Task 6) have not run.

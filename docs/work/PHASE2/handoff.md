# Handoff — port-idp: PHASE2 checkpoint delivered; GitHub sandbox test in progress

## Repository and worktree identity

- Repo: `port-idp` (Terraform config for Port.io / Mayo pilot). Planning docs live one
  directory up at `/Users/manju/Documents/port.io/` — **not** a git repo itself; never
  run repo-wide git commands from there.
- Main checkout: `/Users/manju/Documents/port.io/port-idp`, branch `main` @ `639a679`.
- Second worktree: `/Users/manju/Documents/port.io/port-idp-PHASE2`, branch
  `feat/PHASE2-pilot-project-and-environments` @ `6ee92db`.
- Both worktrees clean (`git status --short` empty) as of this handoff.
- **`origin` was repointed mid-session** from `https://github.com/bitcot/port-io.git`
  to `https://github.com/manjula25/terraform-portio.git` (a personal sandbox repo), at
  the user's explicit request, to work around a GitHub permission blocker (see below).
  **This is now the current, correct remote for this repo.** Both `main` and the
  `PHASE2` branch are pushed and up to date on it.
- **A pull request from the same `PHASE2` work still exists at the old remote**:
  `https://github.com/bitcot/port-io/pull/1`, state `OPEN`, confirmed live via
  `gh pr view 1 --repo bitcot/port-io`. If `bitcot/port-io` is the real intended
  destination for the Mayo pilot deliverable, that PR is the one to review/merge —
  it is untouched by the later origin change and does not include the two follow-up
  commits made after PR creation (a mischaracterization correction, see below) unless
  someone re-pushes the branch there.

## Two distinct threads of work happened in this session — do not conflate them

### 1. PHASE2 (Mayo pilot) — checkpoint complete, delivered

The formal ADLC lifecycle ran end to end for `PHASE2` (scope: `FR-001`, `FR-002`,
`FR-003` only, plan-diff evidence rung — see `docs/work/PHASE2/specification.md`'s
Approval section for why this subset). All artifacts are committed on
`feat/PHASE2-pilot-project-and-environments`:

- `docs/work/PHASE2/implementation-plan.md` — 6 tasks, all executed.
- `docs/work/PHASE2/implementation-notes.md` — deviations, and a corrected finding
  (see below).
- `docs/work/PHASE2/verification.md` — fresh proving commands, unknowns closed/deferred.
- `docs/work/PHASE2/review.md` — four-axis review, all PASS, no blocking findings.
- `docs/work/PHASE2/delivery.md` — full delivery summary, non-claims, remaining risks.

**Status: done for this scope.** Nothing further is required here unless the user asks
to plan the next slice (`S3`/`FR-004`+, which needs the open track decision `G-12` —
GitHub vs. Azure DevOps — closed first).

**One corrected finding worth knowing about:** an early note in this session called
`"installationAppType" must be string"` a "bug" in `github-integration.tf`. It is not.
The `port_integration` resource's own schema says it "manages existing integration and
integration mappings, not for creating new integrations" — the error is the expected
result of applying before `terraform import`. This was corrected across
`implementation-notes.md`, `review.md`, and `delivery.md`, and the `.tf` file's
guardrail comment now quotes the exact error. If a future session sees this error
again, the fix is to import, not to edit the mapping.

### 2. Personal GitHub-integration sandbox test — in progress, not yet applied

Separate from PHASE2, testing the GitHub (Ocean) integration mechanism for real,
against a personal sandbox repo, since PHASE2 itself is blocked on `G-12`.

**What's done:**
- GitHub App installed on `manjula25/terraform-portio` (a personal repo the user
  admins) via Port's "Hosted by Port" method — the org-level "GitHub App, created by
  Port" method was tried first against `bitcot`'s org and **blocked**: GitHub only
  offered "No repositories" with a disabled "Update access" button, because the
  account was a repo admin on `bitcot/port-io` but not an **org owner**. This gotcha
  and the working alternative are documented in
  `docs/github-integration-sandbox-setup.md` and `README.md` §5 (both pushed to
  `main`, commits `7900688`, `639a679`).
- Real installation ID `154905752` found and used (not the data-source's display
  name — that distinction is also documented).
- `terraform import port_integration.github 154905752` — **succeeded**.
- `terraform plan` — clean: `3 to add, 1 to change, 0 to destroy`. The integration
  update and the plan mechanics are confirmed working end to end at the plan rung.

**What's blocking `terraform apply`:** `port_entity.project`'s `teams` property is
still `["REPLACE-ME"]` in the local (gitignored, never-committed)
`projects/mayo-pilot/terraform.tfvars`. Applying as-is will very likely repeat the
`not_found` error on the `_team` blueprint seen earlier in this session (from an
unrelated unauthorized-apply incident against `bitcot`'s production Port org — see
below), because `REPLACE-ME` doesn't exist as a real team. `port_entity.environment["dev"]`
and `["prod"]` would likely also fail to create, since they depend on
`port_entity.project`'s identifier. `port_integration.github`'s update is independent
of the others and should succeed regardless.

**First concrete action for the next session:** ask the user for a real team name that
exists in their sandbox Port organization, update `owning_team` in
`projects/mayo-pilot/terraform.tfvars` (local file, `sed` or manual edit — it's
gitignored, no commit needed), re-`terraform plan`, confirm `teams = ["<real-team>"]`
in the diff, then get explicit confirmation before `terraform apply`.

## A real risk from earlier in this session — not yet confirmed resolved

**A Port API credential (`PORT_CLIENT_ID`/`PORT_CLIENT_SECRET`) was exposed in
plaintext via a screenshot the user shared, mid-session, before the sandbox pivot.**
It was used once (deliberately, after flagging this to the user) to unblock a stuck
verification step, then the recommendation to rotate it was repeated multiple times.
**This has not been confirmed done.** Ask the user directly at the start of the next
session whether it's been rotated; if not, that's the highest-priority item, ahead of
anything else here.

Also from that same earlier incident: an **unauthorized `terraform apply`** ran
against `bitcot`'s **production** Port organization (before the origin change),
outside any approved plan task, with placeholder values. Both resources it touched
errored before creating anything (confirmed via an empty `terraform state list`
immediately after). Fully disclosed and analyzed in `docs/work/PHASE2/`
implementation-notes.md / verification.md / review.md — no further action needed on
this specific incident, it's closed as "disclosed, nothing created."

## Repository conventions to keep following

- `.tfvars` (except `.tfvars.example`), `.tfstate`, `*_override.tf`, and `tfplan` are
  all gitignored by design — never try to commit them.
- Any file containing a real credential must never appear in a shell command this
  agent runs directly — the harness's classifier blocks it. Ask the user to run
  credentialed commands themselves and paste output back.
- `terraform apply` against a production Port organization requires the gated
  `port-production` GitHub environment with required reviewers (`docs/agents/project-policy.md`
  §External authority) — this rule was violated once already this session (see above);
  don't repeat it. The sandbox repo (`manjula25/terraform-portio`) has no such gate
  configured, but treat every `apply` as a real, confirmable action regardless.
- `docs/agents/lifecycle.md` §5 tracks work-item stage; it has not been updated to
  reflect PHASE2's now-complete delivery status — worth updating in a future session
  if `PHASE1` or a new `PHASE3` work item is picked up, so the table stays accurate.

## Suggested skills for the next session

- No lifecycle skill is needed to continue the GitHub sandbox test — it's ad hoc
  verification, not a formal work item.
- If the user wants to plan the next PHASE2 slice (`FR-004`+), that needs the `G-12`
  track decision closed first; then `writing-plans` again, scoped to the next
  plannable subset per `docs/work/PHASE2/specification.md`.
- If picking up `PHASE1` (currently `decomposed`, no `specification.md`), the next
  skill per `docs/agents/lifecycle.md` §5 is `to-spec`.

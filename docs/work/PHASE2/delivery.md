# Delivery

## Work item

**PHASE2** — Mayo Port.io pilot. This delivery covers the plannable subset agreed in
`specification.md`'s Approval section: `FR-001`, `FR-002`, `FR-003`, at the plan-diff (`E-PLAN`)
evidence rung.

## Summary

Sourced the pilot's `environment` entities from a required input variable
(`var.environments`, no default) instead of a hardcoded `dev`/`prod` pair, and added
`cloud_project_id` so the GCP-versus-Port-project distinction (`O-7`) is recorded in data
rather than left to a glossary entry. Asserted, at the plan rung, that the `project` entity
already carries `client`/`status`/`tier` and that `teams` is set exactly once, only at project
level — no source change was needed for either. Nothing was applied to Port by this work.

## Plan artifacts

- `docs/work/PHASE2/implementation-plan.md` — the approved plan, 6 tasks, all executed.
- `docs/work/PHASE2/implementation-notes.md` — deviations (an invalid placeholder value, a
  stale state lock) and the unauthorized-apply finding, disclosed as adjacent, not caused by
  this candidate's own tasks.
- `docs/work/PHASE2/verification.md` — fresh proving commands and their output, unknowns closed
  or deferred by name and owner.
- `docs/work/PHASE2/review.md` — four-axis review, all **PASS**, no blocking findings.
- `docs/work/PHASE2/evidence/fr-003-{red,green}.json`, `fr-003-plan-summary.txt`,
  `fr-001-002.json` — the plan-diff captures themselves.

## Verification

Fresh as of the last `verify.md` run (19 Aug 2026): `./scripts/verify.sh projects/mayo-pilot`
and `./scripts/verify.sh organization` both pass every available rung (`fmt`, `init`,
`validate`, `plan`, and the no-destroy guard on `organization`). `terraform state list` on
`projects/mayo-pilot` is empty; `organization`'s state holds only Phase 1's 9 pre-existing
blueprint resources, untouched by this work.

## Evidence boundary

Plan-diff (`E-PLAN`) only. No `terraform apply` was run as part of this plan's own tasks. No
non-production Port organization exists (`G-6`), so `E-READ`, `E-COUNTER`, and `E-HUMAN` are
not reachable from this repository today for any requirement in scope.

## Non-claims

- Does not claim `FR-001`/`FR-002`/`FR-003` hold at `E-READ`.
- Does not claim `FR-004` through `FR-015` are addressed — all remain exactly as
  `specification.md` states, blocked on `G-11`, `G-12`, `PQ-8`, `PQ-17`, or the `FR-015`
  sponsor decision.
- Does not claim any entity exists in Port as a result of this work.
- Does not claim the credential exposed mid-session (via a screenshot) has been rotated.
- Does not claim independent Port-catalog confirmation that the unauthorized apply attempt
  left nothing behind — only Terraform's own state and the API's error responses support that.

## Remaining risks

1. **The exposed Port credential (`PORT_CLIENT_ID`/`PORT_CLIENT_SECRET`) has not been confirmed
   rotated.** This is the single highest-priority follow-up outside this repository's own
   evidence boundary — a Port-console action, not something any command here can verify.
2. ~~`github-integration.tf` has a live bug~~ — **corrected.** The
   `"installationAppType" must be string"` error is not a config defect: the
   `port_integration` resource's own schema says it "manages existing integration and
   integration mappings, not for creating new integrations," and the error is the expected
   consequence of the unauthorized apply attempting a create instead of a
   `terraform import`. No fix needed in the mapping itself; the file's guardrail comment was
   strengthened to name this exact error so it isn't mistaken for a bug again.
3. **`var.environments`'s map key and its `stage` field are independently settable** — a
   mismatched pair would silently produce a misleading identifier. Deferred until real stage
   data exists to validate against.
4. All prior open points are unchanged: `G-11` (pilot name), `G-12` (track), SSO configuration,
   the running-stages list, GCP read access (`PQ-17`), the `FR-015` exit-test decision, and
   `PQ-8` (registry permission meaning).

## Review status

Four-axis code review (`docs/work/PHASE2/review.md`) against candidate
`ae3943d5...` (short `ae3943d`): repository standards **PASS**, specification fidelity **PASS**,
evidence and risk integrity **PASS**, unnecessary complexity **PASS**. No blocking findings.
Independent specification review (**PASS**) and code-quality review (**APPROVED**) both ran
against the unchanged `.tf`/evidence content at an earlier candidate in this same range
(`df96df6`) and are carried forward, confirmed by diff to be unaffected by the later
documentation-only commits.

## Branch and base

- Branch: `feat/PHASE2-pilot-project-and-environments`
- Worktree: `../port-idp-PHASE2` (sibling of the main `port-idp` checkout)
- Base: `main` at `1d1b57c289c7e2f77e1515b681cff26fa861d254`, confirmed still an ancestor of
  `main` in the primary checkout.

## Commit range

Six commits, `1d1b57c..ae3943d`:

```
950de7e feat(PHASE2): source the pilot's environments from input and record cloud_project_id
67a2787 test(PHASE2): record the plan-rung evidence for FR-001 and FR-002
df96df6 docs(PHASE2): record the evidence rungs reached and the ones that were not
ad0bfbd docs(PHASE2): record implementation notes for the accepted checkpoint
d8764ce docs(PHASE2): verification record for the accepted checkpoint
ae3943d docs(PHASE2): code review record for the accepted checkpoint
```

(`1d1b57c` itself — landing the Phase 1 baseline — is on `main` already and is the base, not
part of this range.)

## Requested external actions

User explicitly requested: push the branch and open a pull request against `main`.

## Executed external actions and observed results

- `origin/main` did not exist — the remote `bitcot/port-io` was completely empty
  (`git ls-remote origin` returned nothing). Confirmed with the user before acting, since this
  is a bigger action than pushing a feature branch: it establishes the repository's entire
  history on the remote for the first time. User confirmed.
- Pushed local `main` (through `1d1b57c`) to `origin/main` — observed: `* [new branch] main -> main`.
- Pushed `feat/PHASE2-pilot-project-and-environments` to `origin` — observed:
  `* [new branch] feat/PHASE2-pilot-project-and-environments -> feat/PHASE2-pilot-project-and-environments`.
- Opened a pull request against `main` via `gh pr create`, body drawn from this delivery
  summary — observed result: **https://github.com/bitcot/port-io/pull/1**.

## Pending actions

- **Rotate the exposed Port credential** — outside this branch's scope but blocking in
  practice; recommended before any further work in this Port organization, regardless of this
  PR's fate.
- PR review and merge — not requested; awaiting the user's own review on GitHub.

# Work Item Context

## Identity and source

`WORK_ITEM_ID`: **PHASE2**

Source: `../mayo-port-prd.md` §8, "Phase 2 — Pilot slice", requirements `P-1` … `P-11`.

Resolved through the standing shortened flow in `docs/agents/workflow.md`. `grill-with-docs`
and `to-prd` skipped: the PRD is an approved specification with checkable "Done when" lines.
This file records the skip rather than implying discovery happened.

Predecessor: `docs/work/PHASE1/` — the model this phase fills with data.

## Summary

Put one real Mayo team into the portal. Their project, their environments, their repositories
arriving automatically, and one button they actually press.

Phase 1 built shapes. This phase is the first time the catalog contains anything true about
Mayo, which is also the first time a mistake costs something.

## Original request

Verbatim requirement headings from the PRD:

- `P-1` Pilot project entity and team assignment
- `P-2` Environments defined, one per running stage
- `P-3` Git integration installed and adopted into Terraform
- `P-4` Two integration settings that decide whether this works
- `P-5` Narrow scope first, widen by PR
- `P-6` Ingestion counters watched on first sync
- `P-7` Everything arrives `experimental`
- `P-8` One self-service action, live and used — a build-and-deploy one
- `P-8a` Dispatched jobs report their outcome back to Port
- `P-9` Registry permission layer
- `P-10` Merge-freeze state surfaced (Track B only)
- `P-11` Google Cloud projects become `environment` records

**Phase 2 exit:** "the pilot team can see themselves in Port — their services, their
repositories and pull requests, one action they actually use."

## Acceptance criteria supplied by source

| Req | Done when |
|---|---|
| `P-1` | a service page shows its owning team without the team being set on the service |
| `P-2` | each running stage has exactly one entity and its cloud and region are set |
| `P-3` | the mapping is in the repo, `terraform plan` is clean immediately after import, and no second integration exists |
| `P-4` | the catalog contains no Ocean-created blueprint, and `grep -r includedFiles` over the repo returns nothing |
| `P-5` | the first sync's entity count matches the pilot team's repository count |
| `P-6` | failed is zero and the three counters are recorded in the PR that widened scope |
| `P-7` | no ingested service is `production` until a human sets it |
| `P-8` | a member of the pilot team has used it at least once without being asked to |
| `P-8a` | three cases end in a definite state in Port — success, job failure, and job killed — and the portal never shows "running" for a job that has stopped |
| `P-9` | one skill and one MCP server are marked approved for one team, and the screen states that Port does not grant access |
| `P-10` | freeze state is visible on the project page, or the requirement is formally deferred with a reason |
| `P-11` | the pilot's stages exist as records sourced from Google Cloud, and the GCP-project-to-Port-project mapping is written into the repo glossary |

## Comments, attachments, and links reviewed

- `../mayo-port-build-spec.md` — `BS-11` (second-writer risk on `service`), `BS-15`–`BS-17`
  (the callback credential), `BD-2`, `BD-5`, `BD-6`
- `../prd-open-questions.md` — `PQ-5`, `PQ-6`, `PQ-8`, `PQ-14`, `PQ-16`, `PQ-17`
- `projects/mayo-pilot/github-integration.tf` — Ocean mapping already drafted at baseline
- `docs/github-ocean-setup.md` — install sequence and the import step

## Code or documentation hints

`projects/mayo-pilot/` already carries a project entity, two environment entities, a
commented service example, and a full Ocean mapping written against the shared model rather
than Ocean's defaults. None of it has been applied. Variables are placeholders.

The Phase 1 override demonstrated exactly what `P-4` warns about: the working organization
already held 54 blueprints from Port's provisioned defaults, including a `githubRepository`
and a rival `service`. That is not a hypothetical failure mode here — it has already
happened once in this tenant and had to be undone.

## Conflicts and ambiguities

1. **The exit test names pull requests; no blueprint holds one.** Phase 2's exit is "their
   services, their repositories and pull requests". `DM-5` added `repository`. Nothing in
   PRD §5 models a pull request, and `P-4` forbids Ocean's `githubPullRequest` because
   default resources must be off. `D-1` defers additional blueprints. So the exit test as
   written cannot currently be met. **This needs a decision, not an assumption** — see
   `slices.md` S5.

2. **Track is undecided.** `G-12` is still open. Track A and Track B differ in integration,
   action backend, and whether `P-10` exists at all. Slices are written to the outcome, with
   the track-specific mechanism named as a variable rather than assumed.

3. **`P-8` was amended after the PRD's own §8 was written.** `BD-6` replaced the
   SailPoint-backed access action with a deploy action, because nothing SailPoint-backed is
   built until we have SailPoint access (`PQ-16`). The access action remains the better demo
   and returns when `PQ-16` closes.

4. **One repository may not equal one service.** `A-5` is a stated assumption, `O-6` is
   unresolved, `PQ-14` asks the question. Heavy monorepo use moves service creation from the
   mapping to something else entirely.

## Sensitive information redacted

No Mayo repository names, team names, or GCP project identifiers are recorded here — none
have been supplied yet. Port credentials remain outside the repository.

A read-only `Member` service account created during Phase 1 for the `F-7` test
(`port-idp-plan@serviceaccounts.getport.io`) exists in the working organization. Its secret
was returned once by Port and is held outside this repository. **It must be rotated before
this pattern is used against a Mayo tenant.**

## Evidence not yet checked

- Which team is the pilot, and whether they are on GitHub or Azure DevOps (`G-11`, `G-12`).
  Nothing downstream can be scheduled without both.
- Whether Port's Azure DevOps integration exists and what it ingests (`G-13`, `PQ-5`).
- Whether the pilot's repositories are one-service-per-repo (`PQ-14`).
- Whether Entra groups match the real delivery squads (`PQ-10`). If they do not, the team
  assigned in `P-1` reflects the org chart rather than the people doing the work.
- Whether Port supports a `Moderator` service account scoped through `moderated_blueprints`
  as the least-privilege callback credential for `P-8a`. The field exists on `_user`;
  the behaviour is untested.
- Whether Google Cloud read access will be granted for `P-11` (`PQ-17`).

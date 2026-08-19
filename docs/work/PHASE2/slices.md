# Vertical Slices

Work item: **PHASE2** — see `context.md` for source, supplied acceptance criteria, and the
four conflicts found while writing this.

## Status

**Approved as a decomposition — 19 Aug 2026, manjula.**

Approved means: the slice boundaries, the dependency order, and the blocker list are agreed and
downstream work may build on them. It does **not** mean the two decisions inside the graph are
made. `S5` still has no acceptance criteria and the track decision still cuts across `S3`, `S6`,
`S7` and `S10`. Approving the shape of the work is not the same as answering what the work is.

Every slice below is blocked on an input nobody has supplied yet. That is the honest state of
Phase 2, and it is why the graph is worth agreeing now: the blockers are the deliverable of
this document, not a footnote to it.

## Dependency graph

```
                    ┌── S2 ──── S9
S1 ─────────────────┼── S6 ──── S7
                    └── S8

S3 ──── S4 ──── S5

S10  (Track B only, independent)
```

`S1` gates almost everything: `project` is a required relation on `environment` and `service`,
so nothing else can be created until the pilot project exists. `S3` and `S4` form the other
chain — the integration must be owned before anything flows through it.

**The track decision cuts across the whole graph.** It is not a slice. It changes the
mechanism inside `S3`, `S6`, `S7` and decides whether `S10` exists at all.

## Requirement coverage

| Requirement | Slice | Blocked on |
|---|---|---|
| `P-1` pilot project and team | S1 | Pilot named (`G-11`); SSO so `_team` exists |
| `P-2` environments per stage | S2 | Which stages actually run |
| `P-3` integration installed and imported | S3 | Track (`G-12`); org name; a human UI handshake |
| `P-4` the two settings that decide it | S3 | same as S3 |
| `P-5` narrow scope first | S4 | Pilot's repository list |
| `P-6` ingestion counters watched | S4 | S3 |
| `P-7` everything arrives experimental | S4 | S3 |
| `P-8` one action, live and used | S6 | What action; CI dispatch credential |
| `P-8a` jobs report back | S7 | S6; a write-scoped Port credential |
| `P-9` registry permission layer | S8 | S1; `PQ-8` |
| `P-10` merge-freeze surfaced | S10 | Track B confirmed |
| `P-11` environments from Google Cloud | S9 | GCP read access (`PQ-17`) |
| **Exit test: pull requests visible** | **S5** | **No blueprint models a pull request — needs a decision** |

Every requirement is claimed. One exit condition is **not** covered by any requirement, which
is the finding in S5.

---

## Slices

### Slice 1: The pilot project exists and owns its team

- **Observable outcome:** A project page shows the pilot with its client, status and tier, and
  a child entity displays the owning team without that team being set on the child.
- **Acceptance criteria:**
  - `project` entity exists with client, status, tier
  - team assigned **at project level only** (`DM-1`)
  - an `environment` created under it shows the team without a team property of its own
- **Requirements covered:** `P-1`.
- **Assumption dependencies:** That Entra groups correspond to the real delivery squad
  (`PQ-10`). If they mirror the org chart, this slice succeeds mechanically and is wrong
  in substance — the rollups will describe reporting lines rather than the people doing the
  work.
- **Preferred seam:** the entity as Port's API returns it, with its resolved ownership.
- **Simplification notes:** Ownership is assigned once here and inherited. Setting a team on
  a service later would create a second writer on a record the git integration owns
  (`BS-11`).
- **Risk exposure:** Low mechanically. The risk is social — assigning the wrong team makes
  every later number wrong in a way no test detects.
- **Evidence needed:** the entity, and a child showing inherited ownership.
- **Dependencies:** none.
- **Blockers:** pilot team named (`G-11`); SSO configured against Entra, because a team
  nobody has signed in from does not exist in Port (`DM-9`).

### Slice 2: One environment per stage that actually runs

- **Observable outcome:** The stages the pilot really deploys to appear, and no others.
- **Acceptance criteria:** exactly one entity per running stage; `cloud` and `region` set;
  `cloud_project_id` recorded so the GCP-versus-Port project collision is settled with data.
- **Requirements covered:** `P-2`.
- **Assumption dependencies:** that the pilot's stages are a subset of `dev`/`test`/`stage`/`prod`.
- **Preferred seam:** the entity list for the `environment` blueprint.
- **Simplification notes:** Hand-declared in the project stack now; sourced from Google Cloud
  in S9. Doing it by hand first means Phase 2 does not wait on `PQ-17`.
- **Risk exposure:** Creating a stage that does not really exist. An environment with nothing
  deployed to it is a lie the scorecard will later reward — `S-1` checks "runs in at least one
  production environment", and an invented prod entity passes that check dishonestly.
- **Evidence needed:** entity list matching a stated list of running stages.
- **Dependencies:** S1.
- **Blockers:** which stages actually run, with regions and GCP project IDs.

### Slice 3: The git integration is installed and owned by Terraform

- **Observable outcome:** The integration syncs, its mapping lives in the repo, and the UI
  mapping editor is off limits from that moment.
- **Acceptance criteria:**
  - installed via a Port-created GitHub App, **not** a PAT
  - `terraform import port_integration.github <installation-id>` done **before** the first
    apply
  - `terraform plan` clean immediately after import
  - exactly one integration exists
  - **"Create default resources" was OFF at install**
  - `grep -r includedFiles` over the repo returns nothing
- **Requirements covered:** `P-3`, `P-4`.
- **Assumption dependencies:** Track A. On Track B the mechanism is unknown — `T-3` forbids
  naming an Azure DevOps endpoint we have not read documentation for.
- **Preferred seam:** the integration's config as Port's API returns it, compared against the
  repo.
- **Simplification notes:** Not a PAT, deliberately: a PAT is a named person's credential, so
  it dies when they leave and attributes every sync to them in the audit log — which matters
  more in a regulated shop than the convenience costs.
- **Risk exposure:** **Highest in the phase, and already realised once in this tenant.**
  Leaving default resources on makes Ocean create `githubRepository`, `githubPullRequest` and
  ~16 others. Phase 1 found 54 such blueprints already present and had to import and override
  two of them. Skipping the import either fails the apply or creates a second empty
  integration beside the real one.
- **Evidence needed:** clean plan post-import; blueprint list showing no Ocean-created types;
  a single integration.
- **Dependencies:** none.
- **Blockers:** track decision (`G-12`); GitHub org name; **a human must do the OAuth
  handshake in the UI** — this is the one UI step `B-3` permits.

### Slice 4: The pilot's repositories appear as services and repositories

- **Observable outcome:** The team opens Port and finds their own repos, correctly owned, and
  nothing that is not theirs.
- **Acceptance criteria:**
  - first sync entity count equals the pilot team's repository count (`P-5`)
  - `failed` count is zero; transformed and filtered recorded in the widening PR (`P-6`)
  - every ingested service is `experimental` (`P-7`)
  - each `service` reaches its `repository` and both carry the project relation
- **Requirements covered:** `P-5`, `P-6`, `P-7`, and `DM-5` in practice.
- **Assumption dependencies:** one repository equals one service (`A-5`, `O-6`, `PQ-14`).
  Monorepos break this and move service creation elsewhere entirely.
- **Preferred seam:** the sync's own counters, plus the entity list.
- **Simplification notes:** Start with one team's repos via `repoSearch` and widen one PR at a
  time. A full-org sync on day one creates hundreds of unowned services, and unowned entities
  are how a catalog starts getting ignored.
- **Risk exposure:** **Any non-zero `failed` is a mapping bug, not a data problem** — most
  likely `lifecycle` or the `project` relation, both required, so a repo that cannot resolve
  them is dropped rather than half-created. Caught here it never reaches a developer; caught
  later it arrives as "the portal is wrong about my service".
- **Evidence needed:** the three counters, and a repo count to compare against.
- **Dependencies:** S3, S1.
- **Blockers:** the pilot's repository list.

### Slice 5: Pull requests are visible — **or the exit test is formally amended**

- **Observable outcome:** The team can see their open pull requests from the portal.
- **Acceptance criteria:** *undefined until a decision is made* — see below.
- **Requirements covered:** none. **That is the finding.**
- **Assumption dependencies:** none — this slice exists because an assumption was found to be
  unsupported.
- **Preferred seam:** undecided.
- **Simplification notes:** Three options, none free:
  1. **Add a `pull_request` blueprint.** Honest, and contradicts `D-1`, which defers
     additional blueprints. It is also a high-churn entity type — `G-9` (Port entity limits)
     becomes relevant immediately.
  2. **Link out per repository.** Cheapest. The portal shows a link, not the PRs. Arguably
     fails "see their pull requests" in spirit while passing it in letter.
  3. **Drop it from the exit test.** Defensible if the pilot does not care, but it must be
     said to the sponsor rather than quietly omitted.
- **Risk exposure:** Phase 2's stated exit condition currently **cannot be met**. `DM-5` was
  written to close this gap and only closed the repository half. Discovering this at the demo
  is far worse than deciding it now.
- **Evidence needed:** a recorded decision, then acceptance criteria derived from it.
- **Dependencies:** S4.
- **Blockers:** **a decision from the sponsor or the PRD's author.** This is a PRD amendment,
  not a local choice.

### Slice 6: One action a developer uses without being asked

- **Observable outcome:** A member of the pilot team pressed the button because it was the
  fastest way to do the thing.
- **Acceptance criteria:** a deploy action dispatches CI and a pilot team member has used it
  at least once **unprompted**.
- **Requirements covered:** `P-8`.
- **Assumption dependencies:** `A-4` — build approvals route to Port's native approval with
  the owning team as approver.
- **Preferred seam:** the action's run record in Port and the dispatched job in CI.
- **Simplification notes:** A deploy action, not a SailPoint-backed access action. `BD-6`:
  nothing SailPoint-backed is built until we have SailPoint access (`PQ-16`) — no stand-in
  backend, no placeholder ticket flow, by the same rule that stops us inventing Azure DevOps
  specifics.
- **Risk exposure:** **The acceptance criterion is behavioural and cannot be faked.** `R-1`:
  if the Port button takes five minutes and asking a teammate takes thirty seconds, developers
  route around Port and the adoption numbers measure clicking rather than usefulness. Picking
  a task nobody actually does fails this slice while passing every technical check.
- **Evidence needed:** an unprompted run by someone not on the platform team.
- **Dependencies:** S1.
- **Blockers:** which task genuinely saves them time; a credential permitted to dispatch their
  CI.

### Slice 7: A dispatched job always ends in a definite state

- **Observable outcome:** The portal never shows "running" for a job that has stopped.
- **Acceptance criteria:** three cases end definite in Port — success, job failure, and job
  killed.
- **Requirements covered:** `P-8a`.
- **Assumption dependencies:** that a write-scoped Port credential can be scoped below Admin.
  **Testable now:** the `_user` blueprint carries a `moderated_blueprints` array alongside
  `port_role: "Moderator"`, which looks like the least-privilege shape `BS-15`–`BS-17` wants.
  Untested.
- **Preferred seam:** the entity Port holds after the job ends, in each of the three cases.
- **Simplification notes:** Shipped once as a reusable final step, identical on both tracks.
  Its credential is distinct from the Terraform credentials and short-lived.
- **Risk exposure:** Without it, Port dispatches a job and never learns what happened, so the
  developer checks the pipeline anyway — which is exactly the `R-1` failure. This is a
  requirement, not a nicety: a button that is not genuinely faster gets routed around.
- **Evidence needed:** three runs, three definite end states, including a killed job.
- **Dependencies:** S6.
- **Blockers:** S6; the callback credential.

### Slice 8: The registries gain their permission layer

- **Observable outcome:** One skill and one MCP server are marked approved for one team, and
  the screen says Port does not grant access.
- **Acceptance criteria:** grants expressed at **both** user and team granularity; `B-6`
  carried on screen, not only in a document.
- **Requirements covered:** `P-9`, completing `DM-16`.
- **Assumption dependencies:** `_team` is synced and real entities exist to scope against.
- **Preferred seam:** the permission configuration as Port returns it, plus the rendered view.
- **Simplification notes:** Phase 1 deliberately shipped these blueprints with zero entities.
  This is the slice that fills them.
- **Risk exposure:** `PQ-8` is open — what "permission" even means on a registry that
  explicitly does not enforce. Building the layer before answering that risks shipping
  something teams read as a grant. **A registry teams believe grants access is worse than no
  registry.**
- **Evidence needed:** one approved skill, one approved MCP server, and the disclaimer visible
  in the UI.
- **Dependencies:** S1.
- **Blockers:** `PQ-8`.

### Slice 9: Environments come from Google Cloud rather than by hand

- **Observable outcome:** Stages exist because they exist in GCP, not because someone typed
  them.
- **Acceptance criteria:** the pilot's stages are sourced from Google Cloud; `stage` derived
  from the project naming convention; the GCP-to-Port project mapping written into the repo
  glossary.
- **Requirements covered:** `P-11`.
- **Assumption dependencies:** that the estate encodes stage as `d`/`t`/`s`/`p` in project
  names, which is why `DM-2` carries four values.
- **Preferred seam:** the `environment` entity list, compared against the GCP project
  inventory.
- **Simplification notes:** Supersedes the hand-declared entities from S2. Doing S2 first
  means Phase 2 is not blocked on GCP access.
- **Risk exposure:** Low. This settles `O-7` with data instead of a glossary entry.
- **Evidence needed:** entities whose source is the GCP inventory.
- **Dependencies:** S2.
- **Blockers:** Google Cloud read access (`PQ-17`).

### Slice 10: Merge-freeze state is visible — Track B only

- **Observable outcome:** Developers see a production freeze before a PR is blocked by it.
- **Acceptance criteria:** freeze state visible on the project page, **or** the requirement
  formally deferred with a stated reason.
- **Requirements covered:** `P-10`.
- **Assumption dependencies:** Track B, where production releases are gated by a
  `MERGE_FREEZE` variable in an Azure DevOps variable group (`IR-6`).
- **Preferred seam:** the project page.
- **Simplification notes:** The signal already exists and is already authoritative. Surfacing
  it is near-zero cost.
- **Risk exposure:** None if deferred honestly. This slice does not exist at all on Track A.
- **Evidence needed:** the state visible, or a written deferral.
- **Dependencies:** none.
- **Blockers:** track decision.

---

## What this graph says out loud

**Nothing in Phase 2 is unblocked.** Every slice waits on an input from Mayo. That is not a
planning failure — it is what "the pilot" means. The work is real and mostly written; the
inputs are not.

**Four answers unblock most of it.** Name the pilot team, confirm their git provider, supply
the org and repository list, and have someone install the integration in the UI. That opens
S1, S3, S4 and the path to S6.

**S5 is the one to settle before anything is demonstrated.** Phase 2's exit test promises
pull requests and no blueprint models one. It is cheaper to amend the exit test now than to
discover it in front of the sponsor.

**The rehearsal organization stops being optional here.** It was deferred while the catalog
held zero entities, which was correct. This is the phase that puts real entities in, and a
mid-apply failure — like the undocumented 200-character limit Phase 1 hit — would then leave
live entities against a schema that no longer matches.

## Approval

Approved by **manjula, 19 Aug 2026**, as the decomposition of PRD Phase 2.

Carried forward, unapproved and unanswered: the `S5` decision (a PRD amendment owned by the
sponsor) and the track decision (`G-12`). Both are recorded as clarifications in
`specification.md` and neither is closed by this approval.

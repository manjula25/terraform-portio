# Implementation Plan — FR-015, the `pull_request` blueprint

Work item: **PHASE2**. Derived from `specification.md` §`FR-015` (decision closed 19 Aug 2026)
and `slices.md` §`S5` (both approved 19 Aug 2026).

## Status

**Approved — manjula, 19 Aug 2026**, after `ponytail` simplification (three fixes applied: the
two `PORT_ACCESS_TOKEN`/curl RED and guard steps replaced with plan-rung `jq` assertions, and the
`G-9` bounded-exposure rationale consolidated to one place). No task below has been executed yet.

## Filename deviation, recorded

`writing-plans` names its output `docs/work/{WORK_ITEM_ID}/implementation-plan.md`. That file
already exists here and is the **delivered, verified** plan for `FR-001`–`FR-003`
(`verification.md`, `review.md`, `delivery.md` all cite it by name). Overwriting it would
destroy a delivery record. This plan therefore lands beside it as
`implementation-plan-fr-015.md`. `implementation-notes.md` is not pre-created; `implement` owns
that artifact.

## Scope

**In scope:** `FR-015` / `S5` only — a custom `pull_request` blueprint in the shared model, and
the GitHub (Ocean) mapping that populates it. **To the plan-diff rung only.**

**Explicitly out of scope, with the reason:**

| Left out | Reason |
|---|---|
| `FR-004`–`FR-006` | Newly plannable after `G-12`, but a separate concern with its own plan. This plan changes the integration's `resources` array; it does not touch installation, `repositoryType`, or scope settings. |
| `FR-007`–`FR-009` | Depend on the pilot's repository list, which Mayo has not supplied. This plan does not change the `repository` kind mapping, so `FR-007`'s counter is unaffected. |
| Closing the `DM-5` gap | See "The finding that shaped this plan". Creating `repository` entities is real work with its own cost against `G-9` and would amend `FR-007`'s success criterion. Deliberately not bundled. |
| Merged/closed pull-request history | The selector admits `states: ["open"]` only. Merged history is the DORA input, which `github-integration.tf:108–114` already places in Phase 4. |
| Any `terraform apply` against production | Gated by the `port-production` GitHub environment with required reviewers (`project-policy.md` §External authority), and additionally gated on `G-9` here — see Preconditions. |

**The evidence ceiling for this plan is `E-PLAN`** (plan-diff assertion). `E-READ` requires an
apply, and until a non-production Port organization exists (`G-6`) that apply is against
production. `FR-015`'s `E-COUNTER` half — confirming the `pull-request` kind resolves cleanly on
a real sync — is **not reachable by this plan** and is recorded as unreached.

## The finding that shaped this plan

`specification.md`'s `FR-015` states the blueprint should be "related to `repository`". **That is
not buildable as written.** Repository evidence:

- `modules/core-blueprints/main.tf:187` defines the `repository` blueprint.
- `organization/main.tf:34` exports its identifier.
- `projects/mayo-pilot/github-integration.tf:70` maps GitHub's `repository` kind onto the
  **`service`** blueprint, deliberately — the comment at lines 61–69 explains why.
- Nothing anywhere creates a `repository` entity.

So `repository` is schema with zero entities, and `DM-5`'s own "Done when" — *"the pilot's
repositories appear as entities and each is reachable from its service"* — is **not currently
met**. A `pull_request` related to `repository` would render every pull request unattached.

**Decision taken 19 Aug 2026 (manjula): relate `pull_request` to `service`.** Rationale, costs,
and the two rejected alternatives are recorded in Task 7's ADR. Two consequences this plan
accepts rather than hides:

1. `FR-015`'s written success criterion says `repository`; Task 8 amends it to `service` and
   names the reason.
2. The `DM-5` gap stays open. It is now recorded as an open item rather than silently carried.

## Preconditions

Three. The first two are decisions; the third is a gate on a later step, not on this plan.

**P-1 — the integration must already be imported.** `port_integration.github` manages an
*existing* integration (`github-integration.tf:16–26`). Every plan command in Tasks 4–6 assumes
`terraform import port_integration.github <installation-id>` has already run in whichever
organization the plan is taken against. In the sandbox it has (installation ID `154905752`, per
`handoff.md`). **If this plan is run anywhere else, import first or Tasks 4–6 produce the
`"installationAppType" must be string` error, which is the missing import, not a mapping bug.**

**P-2 — credentialed commands are run by the user, not by the agent.** `terraform plan` reaches
Port and needs `PORT_CLIENT_ID`/`PORT_CLIENT_SECRET`. Per `handoff.md`, the harness classifier
blocks the agent from running commands that touch a real credential. Every command below marked
**[user runs]** must be executed by the user with output pasted back. The agent may run
`terraform fmt` and file edits directly.

**P-3 — `G-9` gates the real apply, not this plan.** `G-9` (Port's per-blueprint entity limit)
is unresolved (`mayo-port-prd.md` §`G-9`) and this decision is what makes it live. This plan
reaches the plan-diff rung only, which creates nothing, so it is not blocked — the gate binds
before any `terraform apply` that would create pull-request entities in a real organization.
Task 6 records the gate; it does not close it. Why the exposure is bounded rather than fully
open is stated once, in the `states = ["open"]` comment in `github-integration.tf` (Task 5) —
not repeated here.

## Verified vendor facts this plan depends on

Confirmed against Port's GitHub (Ocean) documentation on 19 Aug 2026, not asserted from memory:

| Fact | Value |
|---|---|
| Kind string | `pull-request` |
| Ocean's default blueprint | `githubPullRequest` — **must stay off** (`FR-005`) |
| Repository handle injected by Ocean | `.__repository`, resolving to the repository **name as a string** |
| Selector state filter | `states: ["open"]` is Ocean's own default |
| `.state` values from GitHub | `open` \| `closed` only — **`merged` is not a state**, it is `.merged_at` being non-null |

The last row is the one that bites: mapping `status` straight from `.state` renders every merged
pull request as "closed". Task 5 derives the third value instead.

Sources: [GitHub (Ocean)](https://docs.port.io/build-your-software-catalog/sync-data-to-catalog/git/github-ocean),
[Examples](https://docs.port.io/build-your-software-catalog/sync-data-to-catalog/git/github-ocean/examples/).

---

## Task 0 — Worktree and baseline

`workflow.md` §Worktree policy requires a worktree for any change to `modules/`. This change
touches `modules/core-blueprints/`, so it is required, not optional.

Branch from the `PHASE2` branch tip rather than `main`: this plan edits
`projects/mayo-pilot/github-integration.tf`, whose corrected guardrail comment exists only on
that branch (commit `6ee92db`). Branching from `main` would silently drop it.

Do **not** add these commits to `feat/PHASE2-pilot-project-and-environments` itself — that branch
is under review as `bitcot/port-io#1`, and widening an open PR mid-review is how a reviewed
change stops being reviewed.

```
cd /Users/manju/Documents/port.io/port-idp
git worktree add -b feat/PHASE2-pull-request-blueprint \
  ../port-idp-PHASE2-fr015 feat/PHASE2-pilot-project-and-environments
cd ../port-idp-PHASE2-fr015
git log --oneline -1
git status --short
```

**Expected:** worktree created; `git log` shows `d8adb61 docs(PHASE2): update session handoff — two decisions closed`;
`git status --short` empty.

**Stop if** `git status --short` is non-empty — `implement` and `using-git-worktrees` both verify
a clean baseline first.

No commit for this task.

---

## Task 1 — RED: the organization stack has no `pull_request` blueprint

The public seam is Port's API view of the blueprint, never the `.tf` text
(`project-policy.md` §Evidence levels).

**[user runs]**

```
cd /Users/manju/Documents/port.io/port-idp-PHASE2-fr015/organization
terraform init -input=false
terraform plan -out=tfplan
terraform show -json tfplan > /tmp/org-red.json
jq '[.resource_changes[] | select(.address | test("pull_request"))] | length' /tmp/org-red.json
```

**Expected RED:** `0` — no resource for this blueprint exists in the plan.

Capture into `docs/work/PHASE2/evidence/fr-015-red.json`, matching the shape of the existing
`fr-003-red.json`:

```json
{
  "plan_resources_matching_pull_request": 0
}
```

**No API read here.** This plan's ceiling is `E-PLAN` (see Scope); a direct API read is the
`E-READ` rung, which this plan does not reach. `fr-003-red.json` set the precedent — plan-diff
alone is sufficient RED evidence, because the plan is derived from the provider's own view of
the remote object, not from source text (`project-policy.md` §Evidence levels).

**Commit:** `test(PHASE2): capture FR-015 RED — no pull_request blueprint`

---

## Task 2 — GREEN: add the `pull_request` blueprint

Append to `modules/core-blueprints/main.tf`, after the `ingestion_source` block:

```hcl
####################################################################
# Pull request — a change proposed against a service        (FR-015)
#
# Phase 2's exit test is "their services, their repositories and pull
# requests, one action they actually use". DM-5 closed the repository
# half at schema level; this closes the pull-request half.
#
# D-1 deferred additional blueprints generally. This one is a
# deliberate, recorded exception — mayo-port-prd.md §20 and ADR-002.
# It is not a licence to add more.
#
# T-1: no property or relation identifier below names a git vendor.
####################################################################
resource "port_blueprint" "pull_request" {
  identifier  = "pull_request"
  title       = "Pull Request"
  icon        = "Git"
  description = "A change proposed against a service. Metadata only — never a diff, a comment, or file content (B-1, P-4)."

  properties = {
    string_props = {
      # The provider reports open|closed only. `merged` is derived
      # from a merge timestamp — see the mapping's status expression.
      "status" = {
        title       = "Status"
        description = "merged is derived from a merge timestamp, not reported as a state by the provider."
        required    = true
        enum        = ["open", "merged", "closed"]
      }
      "url" = {
        title  = "Link"
        format = "url"
      }
      # B-1: a handle, never an email. An email here would make the
      # catalog a directory of who changed what, which is a different
      # privacy question than the one G-2 answered.
      "author" = {
        title       = "Author"
        description = "Provider username of whoever opened it. A handle, never an email (B-1)."
      }
      "created_at" = {
        title  = "Opened"
        format = "date-time"
      }
      "updated_at" = {
        title  = "Last Updated"
        format = "date-time"
      }
      "merged_at" = {
        title  = "Merged"
        format = "date-time"
      }
      "closed_at" = {
        title  = "Closed"
        format = "date-time"
      }
    }

    number_props = {
      "pr_number" = { title = "Number" }
    }
  }

  relations = {
    # ADR-002. This points at `service`, not at `repository`, because
    # nothing creates `repository` entities: the git mapping turns a
    # repository into a `service` directly. Relating to a blueprint
    # with no entities would leave every pull request unattached.
    "service" = {
      title    = "Service"
      target   = port_blueprint.service.identifier
      required = true
      many     = false
    }
  }

  ownership = {
    type = "Inherited"
    path = "service.project"
  }
}
```

**The 200-character trap** (`CLAUDE.md` §Lessons, and Phase 1 hit it live). Measure before
planning — the failure lands mid-apply, after earlier resources are written:

```
awk '/^  description = /{ s=$0; sub(/^  description = "/,"",s); sub(/"$/,"",s); print length(s)"  "s }' \
  modules/core-blueprints/main.tf
```

**Expected:** every value under `200`. The new one is 105.

**GREEN assertion — [user runs]:**

```
cd organization
terraform plan -out=tfplan
terraform show -json tfplan > /tmp/org-green.json
jq -r '.resource_changes[] | select(.change.actions != ["no-op"]) | "\(.change.actions|join(","))  \(.address)"' /tmp/org-green.json
```

**Expected GREEN — exactly one line, and no other:**

```
create  module.core_blueprints.port_blueprint.pull_request
```

**Create-and-override guard (`B-4`), the assertion that matters most here.** A shared-model
change that destroys a live blueprint destroys its entities:

```
jq '[.resource_changes[] | select(.change.actions | index("delete"))] | length' /tmp/org-green.json
```

**Expected:** `0`. **Any non-zero value stops this plan** — it means an existing blueprint is
being replaced, not added alongside.

Save `/tmp/org-green.json`'s filtered output to
`docs/work/PHASE2/evidence/fr-015-blueprint-green.json`.

**Commit:** `feat(PHASE2): add pull_request blueprint to the shared model (FR-015)`

---

## Task 3 — Wire the outputs

Append to `modules/core-blueprints/outputs.tf`:

```hcl
output "pull_request_blueprint" {
  description = "Identifier of the pull_request blueprint (FR-015)."
  value       = port_blueprint.pull_request.identifier
}
```

In `organization/main.tf`, add to the `blueprints` output map, after the `repository` line:

```hcl
    pull_request = module.core_blueprints.pull_request_blueprint
```

**Verify — [user runs]:**

```
cd organization && terraform validate && terraform plan -out=tfplan
terraform show -json tfplan | jq '[.resource_changes[] | select(.change.actions|index("delete"))] | length'
```

**Expected:** `validate` exit 0; delete count `0`. An output change alone produces no
`resource_changes` entry, so the create line from Task 2 is still the only one.

**Commit:** `feat(PHASE2): export the pull_request blueprint identifier`

---

## Task 4 — RED: the integration mapping has no `pull-request` kind

**[user runs]**

```
cd /Users/manju/Documents/port.io/port-idp-PHASE2-fr015/projects/mayo-pilot
terraform init -input=false
terraform plan -out=tfplan
terraform show -json tfplan > /tmp/pilot-red.json
jq -r '.resource_changes[] | select(.address=="port_integration.github") | .change.after.config' /tmp/pilot-red.json \
  | jq -r '.resources[].kind'
```

**Expected RED:** a single line, `repository`. No `pull-request`.

**Expected failure mode if P-1 was skipped:** the plan errors with
`"installationAppType" must be string`. That is the missing import, not a mapping defect
(`github-integration.tf:16–26`). Run the import and re-plan; do not edit the mapping.

Capture to `docs/work/PHASE2/evidence/fr-015-mapping-red.json`:

```json
{ "integration_kinds_before": ["repository"] }
```

**Commit:** `test(PHASE2): capture FR-015 RED — mapping has no pull-request kind`

---

## Task 5 — GREEN: map the `pull-request` kind onto the blueprint

In `projects/mayo-pilot/github-integration.tf`, insert a second element into the `resources`
array, after the `repository` element's closing `},` (currently line 105) and before the
closing `]`:

```hcl
      {
        # Pull requests -> our own `pull_request` blueprint. Ocean's
        # default `githubPullRequest` stays OFF. FR-005 forbids an
        # integration-CREATED blueprint; a custom one we point the
        # mapping at does not violate that rule, which is the whole
        # basis of the FR-015 decision.
        #
        # states: ["open"] deliberately, and it is Ocean's own default.
        # Open pull requests are a bounded working set. Merged history
        # is the unbounded one, and it is what makes G-9 (Port's
        # per-blueprint entity limit) a live question rather than a
        # theoretical one. Merged history is also a Phase 4 DORA input,
        # not a Phase 2 one — see the note at the end of this array.
        #
        # DO NOT widen this to ["open","closed"] until G-9 has a
        # written answer from Port support. It is a one-line change and
        # that is exactly why it needs the gate stated here.
        kind = "pull-request"
        selector = {
          query  = "true"
          states = ["open"]
        }
        port = {
          entity = {
            mappings = [{
              # .__repository is injected by Ocean and resolves to the
              # repository NAME as a string — the same value the
              # `repository` kind above uses as its service identifier
              # (".name"). That is what makes the relation below line
              # up without a lookup.
              identifier = ".__repository + \"-\" + (.number|tostring)"
              title      = ".title"
              blueprint  = "\"pull_request\""
              properties = {
                # The provider's .state is open|closed only. "merged"
                # is .merged_at being non-null. Mapping .state straight
                # through would render every merged pull request as
                # "closed", which is wrong on the one transition the
                # exit test is about.
                status = "if .merged_at then \"merged\" elif .state == \"open\" then \"open\" else \"closed\" end"

                # .html_url is the browser link. Ocean's default sample
                # uses .url, which is the API URL — not clickable for a
                # human, and this blueprint exists to be looked at.
                url        = ".html_url"
                author     = ".user.login"
                created_at = ".created_at"
                updated_at = ".updated_at"
                merged_at  = ".merged_at"
                closed_at  = ".closed_at"
                pr_number  = ".number"
              }
              relations = {
                # ADR-002: service, not repository. Nothing creates
                # repository entities.
                service = ".__repository"
              }
            }]
          }
        }
      },
```

Then update the trailing comment block (currently lines 108–114) so it no longer lists
`pull-request` as pending:

```hcl
    # Additional kinds — workflow, workflow-run, dependabot-alert,
    # code-scanning-alert — are added once the blueprints they map onto
    # are decided. They are the input to the DORA-style delivery metrics
    # and to the security dimension of the scorecard, so they arrive in
    # Phase 4, not now. Adding a kind before its blueprint exists
    # produces failed-transform counters, not data.
    #
    # `pull-request` landed in Phase 2 (FR-015) because the phase exit
    # test names it explicitly. Merged-PR history stays a Phase 4
    # concern — see the states filter above.
```

**GREEN assertion — [user runs]:**

```
cd projects/mayo-pilot
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform show -json tfplan > /tmp/pilot-green.json

# 1. Exactly one resource changes, and it is an update, not a replace.
jq -r '.resource_changes[] | select(.change.actions != ["no-op"]) | "\(.change.actions|join(","))  \(.address)"' /tmp/pilot-green.json

# 2. Both kinds are now mapped.
jq -r '.resource_changes[] | select(.address=="port_integration.github") | .change.after.config' /tmp/pilot-green.json \
  | jq -r '.resources[].kind'

# 3. The pull-request mapping points at our blueprint, and the selector is bounded.
jq -r '.resource_changes[] | select(.address=="port_integration.github") | .change.after.config' /tmp/pilot-green.json \
  | jq -r '.resources[] | select(.kind=="pull-request") | {blueprint: .port.entity.mappings[0].blueprint, states: .selector.states, service: .port.entity.mappings[0].relations.service}'

# 4. Nothing is destroyed.
jq '[.resource_changes[] | select(.change.actions|index("delete"))] | length' /tmp/pilot-green.json
```

**Expected GREEN:**

1. `update  port_integration.github` — and nothing else. **A `replace` here stops the plan**:
   replacing the integration drops the adopted installation.
2. Two lines: `repository`, then `pull-request`.
3. `{"blueprint": "\"pull_request\"", "states": ["open"], "service": ".__repository"}`
4. `0`.

Save assertions 2 and 3 to `docs/work/PHASE2/evidence/fr-015-mapping-green.json`.

**Commit:** `feat(PHASE2): map the pull-request kind onto pull_request (FR-015)`

---

## Task 6 — Full ladder, the `FR-005` guard, and the `G-9` gate

**Run every available rung — [user runs]:**

```
cd /Users/manju/Documents/port.io/port-idp-PHASE2-fr015
./scripts/verify.sh
```

**Expected:** `PASS` on formatting, init, validate and plan for both `organization` and
`projects/mayo-pilot`. `SKIP` on policy, lint, and runtime read-back — those three are
unavailable (`project-policy.md` §Evidence levels) and **a skipped rung is not a passed rung**.

**`FR-005` guard — the check this change could plausibly break.** `FR-005` forbids an
integration-created blueprint. Adding a kind is exactly the operation that could cause Ocean to
create `githubPullRequest`. Task 5's own GREEN capture already holds the full desired-state
`resources` array Ocean will act from — no new command or credential is needed to check it:

```
jq -r '.resource_changes[] | select(.address=="port_integration.github") | .change.after.config' \
  /tmp/pilot-green.json \
  | jq '[.resources[].port.entity.mappings[].blueprint | select(. == "\"githubPullRequest\"")] | length'
```

**Expected:** `0`. A non-zero result means "Create default resources" was on at install time and
`FR-005` has regressed — that is a blocking finding, not a note. (An `E-READ` confirmation that
Port's live blueprint list agrees is out of reach at this plan's ceiling, same as everywhere
else in this document — see Scope.)

**Record the `G-9` gate.** Append to `docs/work/PHASE2/evidence/fr-015-g9-gate.md`:

```markdown
# G-9 gate — not closed by this plan

`G-9` (Port's per-blueprint entity limit) is unresolved (`mayo-port-prd.md` §G-9). Not blocked
here — this plan creates no entity — but binds before any `terraform apply` that would. See the
`states = ["open"]` comment in `github-integration.tf` for why the exposure is bounded rather
than resolved.
```

**Commit:** `test(PHASE2): full ladder, FR-005 guard, and the G-9 gate record`

---

## Task 7 — `ADR-002`

The three-part gate in `docs/adr/README.md`, tested honestly:

1. **Hard to reverse?** Yes. `service` is a *required* relation. Changing the target once
   entities exist means destroying and recreating them, against a create-and-override provider.
2. **Surprising without context?** Yes. A `repository` blueprint exists and the specification
   says to relate to it. A reader would reasonably assume this is a mistake.
3. **Real trade-off among alternatives?** Yes — `G-9` exposure, `FR-007`'s counter, and the
   `DM-5` gap all move differently across the three options.

All three pass, and this is a decision **this repository** made that its specification does not
cover — the specification says `repository`. So the record is warranted rather than ceremony.

Create `docs/adr/ADR-002-pull-request-relates-to-service.md` from `ADR-TEMPLATE.md`, keeping its
exact headings (`Context`, `Decision`, `Alternatives considered`, `Consequences`, `Risks`,
`Review trigger`, `Related work`, `Supersession`).

Content requirements, so the record is decision-grade rather than descriptive:

- **Status:** Accepted. **Date:** 2026-08-19. **Owners:** manjula.
- **Context:** the four repository facts from "The finding that shaped this plan" above, with
  file and line references, plus `DM-5`'s unmet "Done when".
- **Decision:** `pull_request.service` is a required single relation to `service`.
- **Alternatives considered:** relate to `repository` and add a second mapping to create
  repository entities — rejected because it doubles entities from one GitHub kind against an
  unresolved `G-9` and breaks `FR-007`'s stated counter; and split `DM-5` into its own work item
  first — rejected because it delays the Phase 2 exit test by a full plan-and-review cycle.
- **Consequences:** `FR-015`'s written criterion is amended (Task 8); the `DM-5` gap stays open
  and is now tracked; if `PQ-14` resolves to monorepos (one repository, many services) this
  relation becomes wrong and needs migrating.
- **Risks:** the `PQ-14` migration risk above, stated with its cost — a required relation
  migration on live entities.
- **Review trigger:** `PQ-14` being answered, or `DM-5`'s gap being closed.

Add the row to the table in `docs/adr/README.md`.

**Commit:** `docs(PHASE2): ADR-002 — pull_request relates to service, not repository`

---

## Task 8 — Amend the specification and record what stayed open

`specification.md` and `slices.md` restate the same facts; both need the change.

In `specification.md` §`FR-015`:

- Amend the success criterion from "related to `repository`" to "related to `service`", with a
  one-line reason and a pointer to `ADR-002`.
- Add the `states: ["open"]` bound to the criterion, so "a real pull request appears as an
  entity" is not read as "all pull requests appear".
- Update the traceability row for `FR-015` to note the plan exists and the ADR is recorded.

In `slices.md` §`S5`: update the status line to match. Do not restate the rationale — point at
`specification.md`.

**Record the `DM-5` gap as an open item.** It was found by this work and must not vanish with
it. Add to `CONTEXT.md`'s unresolved-questions section (`domain.md` §Durable updates directs
open domain questions there):

```markdown
- **`DM-5` is not met.** The `repository` blueprint exists (`modules/core-blueprints/main.tf`)
  but nothing creates `repository` entities — the git mapping turns a repository into a
  `service` directly. `DM-5`'s "Done when" ("the pilot's repositories appear as entities and
  each is reachable from its service") is therefore unsatisfied. Found while planning `FR-015`
  (`ADR-002`), which relates to `service` as a result. Closing this would amend `FR-007`'s
  entity counter and increase `G-9` exposure.
```

**Verify — the agent may run these:**

```
grep -n "repository" docs/work/PHASE2/specification.md | grep -n "FR-015"
grep -rn "DM-5" CONTEXT.md docs/adr/ADR-002-pull-request-relates-to-service.md
```

**Expected:** `FR-015`'s criterion no longer says `repository`; `DM-5` appears in both
`CONTEXT.md` and the ADR.

**Commit:** `docs(PHASE2): amend FR-015 to relate to service; record the DM-5 gap`

---

## Traceability

| Task | Traces to | Evidence produced |
|---|---|---|
| 0 | `workflow.md` §Worktree policy | clean baseline |
| 1 | `FR-015` | `evidence/fr-015-red.json` — RED |
| 2 | `FR-015`, `D-1` exception (`prd` §20), `B-4` | `evidence/fr-015-blueprint-green.json` — GREEN |
| 3 | `FR-015` | validate exit 0 |
| 4 | `FR-015`, `S5` | `evidence/fr-015-mapping-red.json` — RED |
| 5 | `FR-015`, `S5` | `evidence/fr-015-mapping-green.json` — GREEN |
| 6 | `FR-005` guard, `G-9`, `project-policy.md` §Evidence levels | `verify.sh` output, `evidence/fr-015-g9-gate.md` |
| 7 | `ADR` three-part gate, `PQ-14` | `ADR-002` |
| 8 | `FR-015`, `DM-5` | amended spec, `CONTEXT.md` entry |

## What this plan does not claim

- That any requirement holds at `E-READ`, `E-COUNTER`, or `E-HUMAN`. The ceiling is `E-PLAN`.
- That a pull request has appeared as an entity anywhere. Nothing is applied.
- That `G-9` is answered, or that the pilot's PR volume has been estimated.
- That `DM-5` is closed. It is now recorded as open, which it already was in fact.
- That `FR-015`'s `E-COUNTER` half — the `pull-request` kind resolving cleanly on a real sync —
  has been observed. It requires an apply and a sync.
- That `G-12`'s Track A decision has been verified against the pilot's real estate (`PQ-6`).
  This plan builds on Track A because that decision is recorded; it does not confirm it.

## Rollback

Every task is additive: one new blueprint, one new output, one new element in an array, and
documents. Rollback is `git revert` of the relevant commit, then re-plan.

**The one asymmetry to know before approving.** Nothing here is applied, so nothing is
destructive *yet* — but once a future apply creates the blueprint, reverting Task 2 **deletes**
it and its entities, because the provider is create-and-override. After that point, removal is a
migration, not a revert (`main.tf:27–30`).

## Next recommended skill

`ponytail`, to strip accidental complexity from this plan, then `implement` after approval.

# Testable Specification

Work item: **PHASE2**. Requirements and their prose live in the sources below; this document
does not restate them. What it adds is a uniquely identified, individually checkable form of
each one, the seam it is observed through, and the rung of evidence that check can honestly
reach.

## Status

**Approved as a specification — 19 Aug 2026, manjula.** `slices.md` was approved the same day.

**What that approval covers, and what it does not.** The requirement set, their identifiers,
their success criteria and their evidence labels are agreed, and `writing-plans` may build on
them. The three clarifications below are **not** closed by it. Two of them change requirement
content rather than wording:

- **Clarification 1 (`FR-015`, the `S5` exit test)** — `FR-015` still has no success criteria.
  It cannot be planned, and a plan that includes it is inventing acceptance.
- **Clarification 2 (the track, `G-12`)** — decides the mechanism in `FR-004`, `FR-010` and
  `FR-011`, and whether `FR-014` exists. Six of fifteen requirements change content with the
  answer, so a plan written before it lands is rewritten after.

Approving a specification that names its own open questions is the correct move; treating those
questions as answered because the document is approved is not.

- There is no `docs/work/PHASE2/prd.md`. Under the standing shortened flow in
  `docs/agents/workflow.md`, `../mayo-port-prd.md` §8 **is** the approved product requirement
  and `to-prd` was skipped by default. `context.md` records the skip. Every `FR` below traces
  to a numbered `P-*` requirement with a supplied "Done when" line, so the input this skill
  requires exists — it just lives one directory up.

## Source artifacts

| Artifact | What it supplies here |
|---|---|
| `../mayo-port-prd.md` §8 (`P-1`…`P-11`) | the requirements and their "Done when" lines — authoritative |
| `../mayo-port-build-spec.md` | `BS-11`, `BS-15`–`BS-17`, `BD-2`, `BD-5`, `BD-6` — the mechanism constraints |
| `docs/work/PHASE2/slices.md` | slice decomposition `S1`…`S10`, dependency order, blockers |
| `docs/work/PHASE2/context.md` | the four conflicts found during decomposition, and the unchecked evidence |
| `docs/agents/project-policy.md` §Evidence levels | the evidence ladder the labels below are drawn from |
| `../prd-open-questions.md` | `PQ-5`, `PQ-8`, `PQ-10`, `PQ-14`, `PQ-16`, `PQ-17` |

### Evidence labels used below

Drawn from the ladder in `docs/agents/project-policy.md`, not invented here. Every rung below
the one claimed must also pass.

- **`E-PLAN`** — plan-diff assertion. `terraform plan -out=tfplan` then
  `terraform show -json tfplan` asserted with `jq`. The highest rung available without an
  apply, and legitimate contract evidence because the plan comes from the provider's view of
  the remote object, never from the `.tf` text.
- **`E-READ`** — read-back of the object through the Port API after an apply. **In Phase 2
  this means the production organization, because no non-production organization exists
  (`G-6`, a Phase 0 gate).** Every `E-READ` requirement is therefore also human-gated through
  the `port-production` environment. This is the honest limit and it is not papered over.
- **`E-COUNTER`** — the integration's own resync counters (transformed / filtered / failed),
  read from Port after a sync. A form of `E-READ` with a distinct source.
- **`E-HUMAN`** — a named person's recorded judgement, or an observed human behaviour. Used
  where no machine check can substitute; `FR-010` is the clearest case.
- **`E-GREP`** — a repository-text check. **Only ever used for a negative** ("this string
  appears nowhere"), which is a property of the repository rather than a claim about Port.
  Never accepted as evidence that something works.

## Functional requirements

### FR-001: The pilot project exists as a single tenancy boundary

- **Behavior:** One `project` entity represents the pilot engagement, carrying its client,
  status and tier.
- **Source traceability:** `P-1`; `DM-1`.
- **Slice coverage:** `S1`.
- **Success criteria:** exactly one `project` entity exists for the pilot, with `client`,
  `status` and `tier` all set to non-empty values.
- **Evidence label:** `E-PLAN` for the create, `E-READ` for the stored result.
- **Boundary and errors:** The pilot's real name is not yet supplied (`G-11`). Until it is,
  the entity cannot be created against anything but a placeholder, and a placeholder entity in
  a live catalog is worse than an absent one — it will be found and believed.
- **Non-claims:** Does not claim the identifier chosen matches any Mayo system of record.

### FR-002: Ownership is assigned once, at project level, and inherited downward

- **Behavior:** A team is set on the `project` and on nothing beneath it. Child entities
  display the owning team without carrying a team property.
- **Source traceability:** `P-1` ("a service page shows its owning team without the team being
  set on the service"); `DM-1`; `BS-11`.
- **Slice coverage:** `S1`.
- **Success criteria:** a child entity's resolved ownership names the same team as its parent
  project, while that child's own team property is empty.
- **Evidence label:** `E-READ` — resolved ownership is computed by Port and is not visible in a
  plan.
- **Boundary and errors:** A team nobody has signed in from does not exist in Port (`DM-9`), so
  this requires SSO against Entra first. If Entra groups mirror the org chart rather than the
  delivery squad (`PQ-10`), this requirement passes mechanically and is wrong in substance —
  every later rollup then describes reporting lines instead of the people doing the work. No
  check detects that; only `FR-014` does.
- **Non-claims:** Does not claim the assigned team is the correct team.

### FR-003: One environment per stage that actually runs, and no others

- **Behavior:** Each stage the pilot genuinely deploys to has exactly one `environment`
  entity, with its cloud, region and cloud project identifier recorded.
- **Source traceability:** `P-2`; `DM-2`.
- **Slice coverage:** `S2`, superseded in source by `S9`/`FR-013`.
- **Success criteria:** the `environment` entity list for the pilot project matches a written
  list of running stages exactly — no missing entity and no extra one; `cloud`, `region` and
  `cloud_project_id` set on each.
- **Evidence label:** `E-PLAN` for the set of creates, `E-READ` for the stored list.
- **Boundary and errors:** An entity for a stage nothing is deployed to is not a harmless
  extra. `S-1` scores "runs in at least one production environment", so an invented production
  environment makes a service pass that scorecard dishonestly. Over-creation is the failure
  mode to guard, not under-creation.
- **Non-claims:** Does not claim anything is actually deployed to any listed stage. That claim
  needs the `workload` blueprint, which is Phase 4 (`BS-13`).

### FR-004: One git integration exists, installed as an app, owned by Terraform

- **Behavior:** The git integration is installed through a Port-created app, imported into
  Terraform state before any apply, and thereafter configured only from the repository.
- **Source traceability:** `P-3`; `B-4`.
- **Slice coverage:** `S3`.
- **Success criteria:** all four hold — the integration mapping is in the repository;
  `terraform plan` is clean immediately after `terraform import port_integration.<x>
  <installation-id>`; exactly one integration exists in the organization; the credential is an
  app installation, not a personal access token.
- **Evidence label:** `E-PLAN` for the clean-plan-after-import assertion, `E-READ` for the
  integration count and credential type, `E-HUMAN` for the OAuth handshake — the one UI step
  `B-3` permits.
- **Boundary and errors:** Skipping the import either fails the apply or silently creates a
  second empty integration beside the real one, at which point two objects claim the same
  mapping and the repository owns neither. A personal access token dies with the person and
  attributes every sync to them in the audit log, which is a compliance problem before it is
  an inconvenience.
- **Non-claims:** Does not name an Azure DevOps endpoint or resource kind. `T-3` forbids
  inventing specifics for an integration whose documentation has not been read (`PQ-5`), so on
  Track B this requirement states the outcome and leaves the mechanism unnamed. See
  `Clarifications`.

### FR-005: No integration-created blueprint exists in the catalog

- **Behavior:** "Create default resources" is off at install, so the integration creates none
  of its own blueprints.
- **Source traceability:** `P-4` first bullet; `B-5`.
- **Slice coverage:** `S3`.
- **Success criteria:** the organization's blueprint list contains no integration-created type
  — specifically no second service-shaped blueprint and no integration-created repository or
  pull-request type — and every blueprint present is declared in `modules/`.
- **Evidence label:** `E-READ` — the blueprint list as Port returns it.
- **Boundary and errors:** **This has already gone wrong once in this tenant.** Phase 1 found
  54 provisioned default blueprints in the working organization, including a rival `service`,
  and had to import and override two of them. Left on, the integration forks the shared model
  and collides with `modules/core-blueprints/` on a later apply. This is the highest-risk
  requirement in the phase and the one least visible after the fact.
- **Non-claims:** Does not claim the working organization is currently clean of pre-existing
  defaults; it claims no *new* ones arrive from this install.

### FR-006: File content is never attached to an entity

- **Behavior:** The integration mapping never sets `includedFiles`.
- **Source traceability:** `P-4` second bullet; `B-1`.
- **Slice coverage:** `S3`.
- **Success criteria:** `grep -r includedFiles` over the repository returns nothing, and the
  integration configuration as Port returns it contains no such key.
- **Evidence label:** `E-GREP` for the repository, `E-READ` for the live configuration. The
  grep alone is insufficient — the live read is what proves the running integration matches.
- **Boundary and errors:** File content from a Mayo repository is precisely what the
  metadata-only boundary excludes. Crossing it puts Port inside the PHI boundary and reopens
  the whole no-BAA position, which is not a technical decision to make locally.
- **Non-claims:** Does not claim repository *metadata* is free of sensitive strings; names and
  paths still arrive.

### FR-007: The first sync covers exactly the pilot team's repositories

- **Behavior:** Ingestion scope starts at one team's repositories and widens one pull request
  at a time.
- **Source traceability:** `P-5`.
- **Slice coverage:** `S4`.
- **Success criteria:** the first sync's created entity count equals the pilot team's
  repository count, from a repository list stated in advance.
- **Evidence label:** `E-COUNTER` plus `E-READ`, compared against a written repository list.
- **Boundary and errors:** A full-organization sync on day one creates hundreds of unowned
  services, and unowned entities are how a catalog starts being ignored. The failure is
  adoption, not correctness, so nothing red appears when it happens.
- **Non-claims:** Does not claim one repository equals one service. That is assumption `A-5`,
  open as `O-6` and `PQ-14`; heavy monorepo use moves service creation out of the mapping
  entirely and would rewrite this requirement rather than fail it.

### FR-008: The first sync's three counters are recorded, and failed is zero

- **Behavior:** Transformed, filtered and failed counts are read on the first sync and written
  into the pull request that widens scope.
- **Source traceability:** `P-6`.
- **Slice coverage:** `S4`.
- **Success criteria:** `failed` is zero; all three counters appear in the widening pull
  request; a large `filtered` count is investigated as a selector-query error before scope
  widens.
- **Evidence label:** `E-COUNTER`, with the pull request as the durable record.
- **Boundary and errors:** Any non-zero `failed` is a mapping bug, not a data problem — most
  likely `lifecycle` or the `project` relation, both required, so a repository that cannot
  resolve them is dropped rather than half-created. Caught here it never reaches a developer;
  caught later it arrives as "the portal is wrong about my service".
- **Non-claims:** A zero `failed` count does not mean the mapping is right, only that nothing
  was rejected.

### FR-009: Every ingested service arrives non-production

- **Behavior:** Ingestion sets `lifecycle` to `experimental`; promotion is a separate human
  act.
- **Source traceability:** `P-7`.
- **Slice coverage:** `S4`.
- **Success criteria:** no ingested `service` has `lifecycle = production` unless a human set
  it after ingestion, and the mapping contains no path that can produce `production`.
- **Evidence label:** `E-READ` for the entity list, `E-PLAN` for the mapping's default.
- **Boundary and errors:** Ingestion cannot know a service's lifecycle. Defaulting to
  `production` hands every new repository a production scorecard it has not earned, and the
  first thing the team sees is a failing grade for something they never claimed.
- **Non-claims:** Does not prevent a human from promoting wrongly.

### FR-010: One action is used unprompted by someone outside the platform team

- **Behavior:** A build-and-deploy action dispatches the pilot's CI, and a pilot team member
  uses it because it is the fastest route to the outcome.
- **Source traceability:** `P-8` as amended by `BD-6`.
- **Slice coverage:** `S6`.
- **Success criteria:** at least one run of the action, initiated by a pilot team member who is
  not on the platform team and was not asked to run it.
- **Evidence label:** `E-HUMAN` — the action's run record identifies the actor, but "unprompted"
  is a fact about the world that no run record contains.
- **Boundary and errors:** **This criterion cannot be faked and cannot be substituted.** `R-1`:
  if the Port button takes five minutes and asking a teammate takes thirty seconds, developers
  route around Port and the adoption number measures clicking rather than usefulness. Choosing
  a task nobody actually performs fails this requirement while passing every technical check
  attached to it.
- **Non-claims:** No SailPoint-backed access action is built, and no stand-in backend or
  placeholder ticket flow stands in for one — `BD-6` and `PQ-16`, by the same rule as `T-3`.
  The access action returns when `PQ-16` closes; it is the better demonstration and that is not
  a reason to fake it now.

### FR-011: A dispatched job always ends in a definite state in Port

- **Behavior:** Every action-backing pipeline ends with a standard step that reports its result
  back to Port and updates the affected record.
- **Source traceability:** `P-8a`; `BD-5`; `BS-15`–`BS-17`.
- **Slice coverage:** `S7`.
- **Success criteria:** three runs end definite in Port — success, job failure, and job killed —
  and no run leaves the portal showing "running" after the job has stopped.
- **Evidence label:** `E-READ` on the run record and the affected entity, in each of the three
  cases. The killed case is the one that is skipped and the one that matters.
- **Boundary and errors:** The callback credential must be write-scoped, short-lived, and
  distinct from the Terraform credentials. The `Moderator` role with a `moderated_blueprints`
  array looks like the least-privilege shape this needs — **that is an untested reading of the
  `_user` blueprint, not a verified capability**, and if it does not hold the fallback is a
  broader credential, which is a decision rather than a detail.
- **Non-claims:** Does not claim the reported outcome is correct, only that it is definite.

### FR-012: Registry approvals exist at user and team granularity, and say what they are not

- **Behavior:** `skill` and `mcp_server` entities carry approval expressed at both user and
  team level, and the screen states that Port does not grant access.
- **Source traceability:** `P-9`; `DM-16`; `B-6`.
- **Slice coverage:** `S8`.
- **Success criteria:** one skill and one MCP server marked approved for one team; the same
  model expressible for an individual user; the non-enforcement disclaimer visible in the
  rendered view, not only in a document.
- **Evidence label:** `E-PLAN` for the permission configuration, `E-READ` for the stored
  result, `E-HUMAN` for the disclaimer being visible on screen — a UI-rendering effect that the
  plan rung cannot observe.
- **Boundary and errors:** Port shows approval; it does not enforce it. Enforcement lives in
  network and identity policy. **A registry teams believe grants access is worse than no
  registry**, because they will stop asking the system that does grant it.
- **Non-claims:** Does not claim any access is granted, revoked, or certified. See
  `Clarifications` — what "permission" means on a register that explicitly does not enforce is
  open as `PQ-8`.

### FR-013: Environments are sourced from Google Cloud rather than typed

- **Behavior:** `environment` records derive from the GCP project inventory, with `stage`
  derived from the estate's own naming convention.
- **Source traceability:** `P-11`; `BD-2`; `DM-2`.
- **Slice coverage:** `S9`, superseding `S2`.
- **Success criteria:** the pilot's stages exist as records whose source is the GCP inventory,
  and the GCP-project-to-Port-project mapping is written into the repository glossary.
- **Evidence label:** `E-READ` — the `environment` list compared against the GCP project
  inventory.
- **Boundary and errors:** Blocked on Google Cloud read access (`PQ-17`). `FR-003` exists so
  the phase is not blocked waiting for it; when this requirement lands, the hand-declared
  entities from `FR-003` are replaced rather than duplicated, and a duplicate here means two
  entities for one stage.
- **Non-claims:** A GCP project and a Port project are different things. This requirement
  settles `O-7` with recorded data; it does not merge the two concepts.

### FR-014: Merge-freeze state is visible, or its absence is written down

- **Behavior:** Where production releases are gated by a freeze flag, developers see the freeze
  before a pull request is blocked by it.
- **Source traceability:** `P-10`; `IR-6`.
- **Slice coverage:** `S10`.
- **Success criteria:** freeze state visible on the project page — **or** a written deferral
  naming the reason and the person who accepted it. Either outcome satisfies this requirement;
  silence satisfies neither.
- **Evidence label:** `E-READ` for the surfaced state, `E-HUMAN` for the deferral.
- **Boundary and errors:** Track B only. On Track A this requirement does not exist, and the
  deferral branch is the correct outcome rather than a failure. The signal already exists and is
  already authoritative, so surfacing it is near-zero cost — which is why deferring it needs a
  reason.
- **Non-claims:** Does not enforce or lift a freeze; Port reflects the flag, it does not own it.

### FR-015: The stated exit condition is either met or formally amended

- **Behavior:** Phase 2's exit test — "their services, their repositories and pull requests,
  one action they actually use" — is satisfied in full, or amended by whoever owns the PRD.
- **Source traceability:** Phase 2 exit line in `../mayo-port-prd.md` §8. **Traces to no `P-*`
  requirement, which is the finding.** `DM-5` added `repository` and closed only half the gap;
  nothing in PRD §5 models a pull request, `P-4`/`FR-005` forbids the integration's own
  pull-request blueprint, and `D-1` defers additional blueprints.
- **Slice coverage:** `S5`.
- **Success criteria:** *not statable until the decision below is made.* Acceptance criteria are
  derived from the chosen option, not before it.
- **Evidence label:** `E-HUMAN` — a recorded decision, then whichever label the chosen option
  implies.
- **Boundary and errors:** As written, **the exit condition cannot currently be met**. The three
  options and their costs are set out in `slices.md` `S5`: add a `pull_request` blueprint
  (honest, contradicts `D-1`, and makes the entity-limit question `G-9` live immediately); link
  out per repository (cheapest, shows a link rather than the pull requests, passes the letter
  and arguably not the spirit); or drop it from the exit test (defensible if the pilot does not
  care, but it must be said to the sponsor rather than quietly omitted).
- **Non-claims:** This is a PRD amendment, not a local choice, and this specification does not
  make it. Discovering it at the demonstration is far worse than deciding it now.

## Non-functional constraints

**Preconditions, not requirements.** Every requirement above is blocked on an input nobody has
supplied. That is what "the pilot" means, and it is recorded here rather than dressed up as
progress:

| Input needed | Blocks | Owner |
|---|---|---|
| Pilot team named (`G-11`) | `FR-001`, and transitively everything | Mayo delivery |
| Git provider confirmed (`G-12`) | `FR-004`–`FR-009`, `FR-014` | Mayo engineering |
| Git organization name and repository list | `FR-004`, `FR-007`, `FR-008` | Mayo engineering |
| A human to complete the OAuth handshake in the UI | `FR-004` | Mayo + platform |
| SSO configured against Entra | `FR-002`, `FR-012` | Mayo identity |
| The list of stages that actually run, with regions and GCP project IDs | `FR-003` | Mayo engineering |
| A credential permitted to dispatch the pilot's CI | `FR-010` | Mayo engineering |
| Google Cloud read access (`PQ-17`) | `FR-013` | Mayo cloud |

Four answers open most of the graph: name the team, confirm the provider, supply the
organization and repository list, and have someone install the integration.

**Constraints that hold across every requirement:**

1. **Metadata only.** Names, links, counts, dollars. No PHI, no secrets, no prompt or
   completion content. `FR-006` is where this is checked; the constraint applies everywhere.
2. **Port is not an access system of record.** `FR-012` shows approval and states plainly that
   it grants nothing.
3. **Configuration as code.** The only permitted UI action in this phase is the OAuth handshake
   in `FR-004`. Everything else is in the repository or does not exist.
4. **One writer per record.** The git integration owns ingested `service` records; Terraform
   must not also set their properties (`BS-11`). The provider is create-and-override, so a
   second writer silently empties whatever it does not declare.
5. **One shared model.** No forked or per-project blueprint. `FR-005` is the specific guard.
6. **The rehearsal organization stops being optional here.** It was correctly deferred while
   the catalog held zero entities. This is the phase that puts real entities in, so a mid-apply
   failure — like the undocumented 200-character limit Phase 1 hit — would leave live entities
   against a schema that no longer matches. Every `E-READ` label above is currently a read
   against production, and that is a stated limit, not an accepted one.
7. **Credential hygiene.** The read-only `Member` service account created in Phase 1 for the
   `F-7` test must be rotated before this pattern is used against a Mayo tenant.
8. **Terraform 1.15.8**, matching CI. `./scripts/verify.sh` runs the available rungs and names
   the unavailable ones as skipped. `conftest`/OPA, `tflint`, and runtime read-back against a
   non-production organization are not installed or do not exist; none may be claimed.

## Clarifications

Three, which is the limit. Each is a decision someone else owns, not a gap in this document.

1. `[NEEDS CLARIFICATION: Phase 2's exit test promises pull requests and no blueprint models
   one — is the resolution a new pull_request blueprint (contradicting D-1 and making G-9 live),
   a per-repository link out, or an amendment of the exit test? This is a PRD amendment and
   blocks FR-015's acceptance criteria entirely.]`
2. `[NEEDS CLARIFICATION: Track A (GitHub) or Track B (Azure DevOps) — G-12. It changes the
   integration mechanism in FR-004, the action backend in FR-010 and FR-011, and decides whether
   FR-014 exists at all. T-3 forbids naming Azure DevOps specifics before its documentation is
   read (PQ-5), so the mechanism stays a variable until this closes.]`
3. `[NEEDS CLARIFICATION: What does "permission" mean on a registry that explicitly does not
   enforce access — PQ-8? FR-012 cannot state honest acceptance beyond "the grant is recorded
   and the disclaimer is visible" until this is answered, and building the layer first risks
   shipping something teams read as a grant.]`

Deliberately **not** raised as clarifications, because they are missing inputs or untested
capabilities rather than open questions: the pilot's identity, the repository list, the running
stages, GCP access, whether one repository equals one service (`PQ-14`), whether Entra groups
match delivery squads (`PQ-10`), and whether a `Moderator` credential scoped through
`moderated_blueprints` works. The first four arrive from Mayo; the last three are checks to run,
and each is recorded on the requirement it affects.

## Traceability matrix

| FR | Requirement | Slice | Highest evidence rung | Blocked on |
|---|---|---|---|---|
| FR-001 | `P-1` | `S1` | `E-READ` | `G-11` |
| FR-002 | `P-1`, `DM-1` | `S1` | `E-READ` | SSO; `PQ-10` in substance |
| FR-003 | `P-2`, `DM-2` | `S2` | `E-READ` | stage list |
| FR-004 | `P-3` | `S3` | `E-READ` + `E-HUMAN` | `G-12`; org name; UI handshake |
| FR-005 | `P-4` | `S3` | `E-READ` | `G-12` |
| FR-006 | `P-4` | `S3` | `E-READ` + `E-GREP` | `G-12` |
| FR-007 | `P-5` | `S4` | `E-COUNTER` | repository list |
| FR-008 | `P-6` | `S4` | `E-COUNTER` | `FR-004` |
| FR-009 | `P-7` | `S4` | `E-READ` | `FR-004` |
| FR-010 | `P-8`, `BD-6` | `S6` | `E-HUMAN` | task choice; CI credential |
| FR-011 | `P-8a`, `BD-5`, `BS-15`–`BS-17` | `S7` | `E-READ` | `FR-010`; callback credential |
| FR-012 | `P-9`, `DM-16` | `S8` | `E-READ` + `E-HUMAN` | `PQ-8` |
| FR-013 | `P-11`, `BD-2` | `S9` | `E-READ` | `PQ-17` |
| FR-014 | `P-10`, `IR-6` | `S10` | `E-READ` or `E-HUMAN` | `G-12` |
| FR-015 | Phase 2 exit line — **no `P-*`** | `S5` | `E-HUMAN` | sponsor decision |

Every `P-*` requirement in PRD §8 is covered exactly once. Every slice `S1`…`S10` is claimed by
at least one `FR`. `FR-015` is the only requirement with no `P-*` source, and that asymmetry is
the finding rather than an oversight.

Coverage the other way, so nothing hides: `P-1` splits into `FR-001` and `FR-002` because
"the project exists" and "ownership is inherited" fail independently. `P-4` splits into `FR-005`
and `FR-006` because they are two settings with two different consequences. `S2` and `S9` both
produce `environment` records, by design and in that order, so `FR-003` and `FR-013` are
sequential rather than alternative.

## Approval

Approved by **manjula, 19 Aug 2026**, against the PRD's own "Done when" lines.

`slices.md` approved the same day. Two gates from the original list remain open and were **not**
satisfied by this approval:

| Gate | State | Effect on `writing-plans` |
|---|---|---|
| Clarification 1 — the `S5` / `FR-015` exit-test decision | **Open.** Owned by the sponsor; it is a PRD amendment. | `FR-015` is out of plan scope. Nothing in a plan may claim to satisfy the Phase 2 exit test until it closes. |
| Clarification 2 — track (`G-12`) | **Open.** Mayo engineering. | `FR-004`, `FR-005`, `FR-006`, `FR-010`, `FR-011`, `FR-014` cannot be planned to a mechanism. Plan them to the outcome or leave them for a second pass. |
| Clarification 3 — `PQ-8`, registry permission meaning | **Open.** | `FR-012` plannable only as far as "the grant is recorded and the disclaimer is visible". |

So the plannable set today is `FR-001`, `FR-002`, `FR-003`, and `FR-013` when GCP access lands —
each still gated on a Mayo input listed under Non-functional constraints. That is what a first
plan should cover, and it should say plainly what it leaves out.

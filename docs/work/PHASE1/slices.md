# Vertical Slices

Work item: **PHASE1** — see `context.md` for source, supplied acceptance criteria, and the
five conflicts resolved along the way.

## Status

**Approved, partially delivered.** S1, S2, S3 and S7's assumption test are **met**.
S4, S5, S6, S8 and S9 are approved as a graph but blocked or deferred.

Everything Phase 1 could deliver without a git remote, a billed GCP project, or a second
Port organization is delivered. What remains is blocked on inputs, not on work.

Phase 1 will exit with `F-2` and `F-6` explicitly deferred, each naming its blocker, rather
than silently unmet. Anyone reading "Phase 1 done" would otherwise assume a rehearsal
organization and state locking exist. Neither does.

## Dependency graph

```
S1 ──┬── S3
S2 ──┘

S4 ──────────┬── S8
S5 ──┬── S6  │
     ├── S7 ─┘
     └── S8

S9   (independent, deferred by decision)
```

S1 and S2 are independent of everything. S3 needs S1 applied. S6, S7 and S8 all sit behind
S5, so a parked repository host parks three slices, not one.

## Requirement coverage

| Requirement | Slice | State |
|---|---|---|
| `F-1` repository structure | — | Met at baseline; verified, not rebuilt |
| `F-2` two-organization promotion | S9 | **Deferred by decision** — see below |
| `F-3` provider pinned, credentials from environment | — | Met at baseline; verified `2.23.1` |
| `F-4` plan-and-apply pipeline | S5 | Blocked — no remote |
| `F-5` `modules/` merge protection | S6 | Blocked — no remote |
| `F-6` GCS state with locking | S4 | Blocked — GCP billing disabled |
| `F-7` plan read-only, apply write | S7 | **Assumption verified**; CI wiring blocked on S5 |
| `F-8` blueprints applied | S1, S3 | **Met** — nine live, registries empty, no drift |
| `DM-1`…`DM-19` (via `F-8`) | S1 | Written and plan-verified |

Every Phase 1 requirement is claimed by exactly one slice. Nothing is uncovered; four are
blocked on inputs outside this repository.

---

## Slices

### Slice 1: The shared model exists in Port, applied from git

- **Observable outcome:** A person opens Port and sees nine blueprints matching
  `modules/core-blueprints/`. Nobody clicked to create them.
- **Acceptance criteria:**
  - All nine return `200` from `GET /v1/blueprints/{id}`
  - `terraform plan` immediately afterwards reports no changes
  - `skill` and `mcp_server` hold zero entities (`DM-16`)
  - `grep -r "client_secret" *.tf` finds no variable; state holds no credential (`F-3`)
- **Requirements covered:** `F-8`, and `DM-1`…`DM-19` transitively.
- **Assumption dependencies:** That overriding Port's provisioned `service` and `environment`
  is acceptable. Confirmed by the user, having been shown what it removes.
- **Preferred seam:** Port's API view of each blueprint, read back after apply. Not the `.tf`
  source text — see the lesson in `CLAUDE.md`.
- **Simplification notes:** The registry disclaimer is one `local` interpolated into three
  descriptions, so `B-6`'s "verbatim" cannot drift between them. `service` uses a literal
  `"service"` for its self-relation because referencing a resource from inside itself is a
  Terraform dependency cycle.
- **Risk exposure:** **High, and realised once.** The provider is create-and-override, and
  the first apply failed mid-flight on Port's undocumented 200-character description limit
  after seven blueprints were already written. `plan` does not catch it. Blueprint and entity
  backups were taken first, to `../backups/port-2026-08-18/`.
- **Evidence gathered 2026-08-18:** all nine blueprints return `200`; a follow-up
  `terraform plan` on `organization/` exits `0` with "No changes. Your infrastructure matches
  the configuration." That clean plan is the real proof — it says the repository and the live
  catalog agree, which is what `B-3` actually claims.
- **Dependencies:** none.
- **Blockers:** none. **Met.**

### Slice 2: Local and CI Terraform agree

- **Observable outcome:** Evidence produced on a laptop means the same thing as evidence
  produced in CI.
- **Acceptance criteria:** `terraform_version` in both workflows equals the local binary;
  `fmt -check` and `validate` pass on it.
- **Requirements covered:** none directly — it makes every other slice's evidence
  trustworthy.
- **Assumption dependencies:** That CI may move up. Safe: CI had never run, because no remote
  existed.
- **Preferred seam:** the pinned version in `.github/workflows/*.yml`.
- **Simplification notes:** Aligned CI up to 1.15.8 rather than downgrading local to 1.9.8.
  Terraform refuses to read state written by a newer version, so downgrading meant rebuilding
  state from nine re-imports to save a version number.
- **Risk exposure:** Low. Reasoning recorded in `docs/agents/workflow.md` so it is not
  silently reverted by someone who reads only the diff.
- **Evidence needed:** `terraform version` beside the workflow pins.
- **Dependencies:** none.
- **Blockers:** none. **Done.**

### Slice 3: No invalid entities in the catalog

- **Observable outcome:** `environment` holds zero entities, so nothing renders as invalid
  against the new required fields.
- **Acceptance criteria:** the three Port demo entities (`staging`, `test`, `production`) are
  gone; `GET /v1/blueprints/environment/entities` returns an empty list.
- **Requirements covered:** `F-8` tail.
- **Assumption dependencies:** That the three carry no information. Verified — their
  `properties` objects are empty; only titles exist.
- **Preferred seam:** `DELETE /v1/blueprints/environment/entities/{id}`.
- **Simplification notes:** Deleted rather than backfilled. Backfilling would invent a stage
  and a project relation for environments nobody deployed anything to.
- **Risk exposure:** Low, and this is the one deletion Phase 1 performs. `N-3` says dead
  things are marked, not deleted — that rule protects records with history. These have none
  and predate the model. Backed up regardless.
- **Evidence gathered 2026-08-18:** all three returned a delete success;
  `GET /v1/blueprints/environment/entities` now returns zero. `skill` and `mcp_server` also
  confirmed at zero, satisfying `DM-16`'s Phase 1 condition.
- **Dependencies:** S1.
- **Blockers:** none. **Met.**

### Slice 4: State lives in GCS and a concurrent apply is refused

- **Observable outcome:** Two people cannot both win an apply.
- **Acceptance criteria:** versioned bucket, one prefix per stack; a second concurrent apply
  is refused by the lock; `organization/backend_override.tf` deleted.
- **Requirements covered:** `F-6`.
- **Assumption dependencies:** that a GCP project with billing is available to hold it.
- **Preferred seam:** `terraform init -migrate-state`.
- **Simplification notes:** State currently sits at `../.tfstate-local/`, outside the
  repository and gitignored, via a documented backend override that names its own removal
  steps.
- **Risk exposure:** **Live.** Local state has no locking at all. Single-machine use is safe;
  a second operator is not. This is stated rather than assumed safe.
- **Evidence needed:** two concurrent applies, one refused.
- **Dependencies:** none.
- **Blockers:** **billing disabled on `mayo-base-462710`**, and no target project chosen.

### Slice 5: A pull request shows its plan before a human reads the diff

- **Observable outcome:** the plan comment exists as the review artifact `B-3` and `S-7`
  depend on.
- **Acceptance criteria:** a PR touching one stack renders a plan comment; an unreviewed
  change cannot reach production.
- **Requirements covered:** `F-4`.
- **Assumption dependencies:** GitHub Actions, i.e. Track A. If the pilot is Track B this
  slice is rewritten as an Azure DevOps pipeline (`PQ-5`).
- **Preferred seam:** the PR comment itself.
- **Simplification notes:** Workflows already exist and plan only the stacks a PR touches,
  fanning out to every project stack when `modules/` changes — the blast radius `S-7` asks
  for.
- **Risk exposure:** Untested. Written but never executed.
- **Evidence needed:** a real PR with a plan comment on it.
- **Dependencies:** none.
- **Blockers:** **no git remote; hosting decision parked.**

### Slice 6: `modules/` cannot be merged without platform-team review

- **Observable outcome:** a project lead cannot change the shared model alone.
- **Acceptance criteria:** a PR touching `modules/` requires platform-team review; one
  touching only `projects/` does not.
- **Requirements covered:** `F-5`; enforces `B-5`, and `B-4`'s done-when names it.
- **Assumption dependencies:** a platform team exists as a group on the host.
- **Preferred seam:** `CODEOWNERS` plus branch protection.
- **Simplification notes:** `CODEOWNERS` does not exist yet. `README.md` already lists it as
  deliberately absent.
- **Risk exposure:** Until this lands, `B-5` is a convention rather than a control.
- **Evidence needed:** a blocked PR.
- **Dependencies:** S5.
- **Blockers:** S5.

### Slice 7: The plan job cannot mutate Port

- **Observable outcome:** a compromised or mistaken plan job cannot change the catalog.
- **Acceptance criteria:** plan succeeds with a `Member` service account; apply with the same
  credential fails.
- **Requirements covered:** `F-7`.
- **Assumption dependencies:** that `Member` can read blueprint definitions, not only
  entities. **VERIFIED 2026-08-18 — it can.** `F-7` is implementable as written.
- **Preferred seam:** two service accounts on the `_user` blueprint —
  `port_type: "Service Account"`, `port_role: "Member"` for plan and `"Admin"` for apply.
  Confirmed against the live `_user` schema.
- **Simplification notes:** Port has no separate API-key resource; credentials come back once
  in `additional_data` on entity creation and are never shown again.
- **Risk exposure:** Port documents `Member` as "read-only **plus permissions to execute
  self-service actions**". So it is read-only with respect to the model, which is what `F-7`
  needs, but the PRD's phrase "read-only credentials" is generous. Re-check once Phase 2
  ships actions.
- **Evidence gathered 2026-08-18**, against a real `Member` service account
  (`port-idp-plan@serviceaccounts.getport.io`) in the working organization:

  | Probe | Result | Reading |
  |---|---|---|
  | `GET /v1/blueprints` | `200` | list readable |
  | `GET /v1/blueprints/service` | `200` | **definitions readable — the blocking unknown** |
  | `PATCH /v1/blueprints/ingestion_source` (no-op) | `403 missing_permissions` | cannot modify the model |
  | `POST /v1/blueprints` | `403 insufficient_scope`, missing `create:blueprints` | cannot extend the model |
  | `terraform plan` on `organization/` | `exit=0`, "No changes" | **the plan job works read-only** |

  The no-op `PATCH` was chosen deliberately: it sends the description already stored, so a
  success would have proved permission while changing nothing. An earlier probe deleting a
  non-existent blueprint returned `404` rather than `403` — Port checks existence before
  permission, so absence of a resource cannot stand in for absence of permission.

- **Dependencies:** S5 for the CI half. The assumption test was unblocked and has now run.
- **Blockers:** S5 for wiring only. The requirement itself is sound.

### Slice 8: Credentials come from Secret Manager, not repository secrets

- **Observable outcome:** no Port credential exists in the repository, in state, or as a
  stored CI secret.
- **Acceptance criteria:** workload identity federation resolves both credentials at run
  time; a state inspection finds no secret material (`N-2`).
- **Requirements covered:** `F-7`.
- **Assumption dependencies:** the same GCP project as S4.
- **Preferred seam:** GCP Secret Manager plus workload identity federation. `plan.yml`
  already requests `id-token: write` for it.
- **Simplification notes:** none — this is the standard path.
- **Risk exposure:** Credentials currently live in a local `.env`. Gitignored in both
  directories and verified, but it is a file on a laptop.
- **Evidence needed:** a CI run that authenticates with no stored secret.
- **Dependencies:** S4, S5.
- **Blockers:** S4, S5.

### Slice 9: The same Terraform applies to a rehearsal organization first

- **Observable outcome:** a shared-model change is proven somewhere harmless before it
  reaches the catalog people use.
- **Acceptance criteria:** one blueprint change lands in non-production, is reviewed, then
  production, with no UI step.
- **Requirements covered:** `F-2`; mitigates `R-4` and `B-4`.
- **Assumption dependencies:** that Mayo's Port account permits a second organization.
  Unknown — `G-4` has not been asked.
- **Preferred seam:** a second Port organization under the same account, selected per stack.
- **Simplification notes:** A Port **organization** used as dev versus production is not the
  **`environment` blueprint**. Same word, two levels apart. Already in the `CONTEXT.md`
  glossary.
- **Risk exposure:** **This is the slice that prevents the failure S1 already demonstrated.**
  A malformed property passed `fmt`, `validate` and `plan`, then broke mid-apply. With zero
  entities that cost nothing; with the pilot's services in place it would leave live entities
  against a schema that no longer matches.
- **Evidence needed:** one change demonstrated through both organizations.
- **Dependencies:** none.
- **Blockers:** **Deferred by user decision, 2026-08-18.** Acceptable while the catalog holds
  no entities. It stops being acceptable when Phase 2 registers real services, which is the
  point at which `G-4` must have been asked and answered.

---

## Approval

Graph approved by the user on 2026-08-18. Scope narrowed the same day: S5, S6 and S9 parked
by decision, S4 blocked externally.

**Phase 1 will be recorded as exited with `F-2` and `F-6` deferred**, each naming its blocker,
rather than reported as complete. The next person reading "Phase 1 done" would otherwise
assume a rehearsal organization and state locking exist. Neither does.

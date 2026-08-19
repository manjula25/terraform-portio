# Implementation Plan

Work item: **PHASE2**. Derived from `specification.md` (approved 19 Aug 2026) and
`slices.md` (approved the same day).

## Status

**Draft — awaiting approval.** No task below has been executed.

## Scope, and what it deliberately leaves out

`specification.md` §Approval names the plannable set itself, and this plan does not widen it:

> "So the plannable set today is `FR-001`, `FR-002`, `FR-003`, and `FR-013` when GCP access
> lands — each still gated on a Mayo input listed under Non-functional constraints. That is what
> a first plan should cover, and it should say plainly what it leaves out."

**In scope:** `FR-001`, `FR-002`, `FR-003` — slices `S1` and `S2` — **to the plan-diff rung
only**.

**Explicitly out of scope, with the reason:**

| Left out | Reason |
|---|---|
| `FR-004`–`FR-006`, `FR-010`, `FR-011`, `FR-014` | Clarification 2 (`G-12`, the track) is open. `T-3` forbids naming a mechanism for an integration whose documentation has not been read. |
| `FR-007`–`FR-009` | Depend on `FR-004` and on a repository list Mayo has not supplied. |
| `FR-012` | Clarification 3 (`PQ-8`) is open. |
| `FR-013` | Blocked on Google Cloud read access (`PQ-17`). `FR-003` exists so this phase does not wait for it; `S9` replaces `S2`'s entities when it lands. |
| `FR-015` | Clarification 1 is a PRD amendment owned by the sponsor. **No task here claims to satisfy the Phase 2 exit test.** |
| Any `terraform apply` | Gated by the `port-production` GitHub environment with required reviewers (`project-policy.md` §External authority), and the pilot is unnamed (`G-11`). |
| The commented `example_service` block in `projects/mayo-pilot/main.tf` | `service` records are the git integration's to write (`BS-11`). Uncommenting it adds a second writer — the blocking defect class in `project-policy.md` §Risk area 2. It stays commented. |

**The evidence ceiling for this plan is `E-PLAN`.** `E-READ` requires an apply, and until a
non-production organization exists (`G-6`) that apply is against production. So:

- `FR-001` — its `E-PLAN` half is planned here; its `E-READ` half is not reachable.
- `FR-002` — the spec labels this `E-READ` only, because resolved ownership is computed by Port
  and never appears in a plan. **What is reachable now is the negative half**: that no entity
  beneath the project carries a team. That is a plan-rung assertion and it is what Task 5 checks.
  The positive half — a child *displaying* the inherited team — is recorded as unreached.
- `FR-003` — its `E-PLAN` half is planned here. The *set* of stages cannot be made correct
  without the stage list, so Task 4 makes the set an input rather than baking a guess in.

## Preconditions

Three, and the first two need a decision before Task 1 runs.

**P-1 — 899 uncommitted lines of Phase 1 work sit on `main`.** Confirmed:

```
git status --short
git diff --stat   # 14 files, 899 insertions, 87 deletions
```

`modules/core-blueprints/main.tf` alone is +759. `using-git-worktrees` and `implement` both
verify a repository baseline first, and this is not one. **This plan does not decide what
happens to that work** — it is `PHASE1`'s, and `PHASE1` is still at the `decomposed` stage with
no `specification.md` (`lifecycle.md` §5). Task 1 commits it as a baseline so `PHASE2` has
something to branch from; approving this plan is approving that. If you would rather take
Phase 1 through its own review first, stop here and say so — every later task assumes a clean
tree.

**P-2 — `PORT_CLIENT_ID` and `PORT_CLIENT_SECRET` are unset in this shell.** Confirmed.
Without them `terraform init` and `terraform plan` cannot reach Port, so no task below can
produce its evidence. Export both before Task 2. They come from the environment and never from
a variable, a default, an output, or a `.tfvars` file (`project-policy.md` §Risk area 5).

**P-3 — Terraform 1.15.8.** Confirmed installed and matching the CI pin.

## Inputs still missing, which this plan works around rather than waits for

| Input | Owner | How this plan handles it |
|---|---|---|
| Pilot team named (`G-11`) | Mayo delivery | Values live only in a gitignored `terraform.tfvars`. Nothing placeholder is committed and nothing is applied, so no placeholder entity reaches a live catalog — the failure `FR-001` §Boundary names. |
| Which stages actually run, with regions and GCP project IDs | Mayo engineering | Task 4 turns the hardcoded `dev`/`prod` pair into a required variable, so the set arrives as input. Over-creation is the failure mode `FR-003` guards, and a hardcoded guess is exactly that. |
| SSO against Entra, so `_team` exists (`DM-9`) | Mayo identity | Only affects apply-time and `E-READ`. No plan-rung task depends on it. |

---

## Tasks

### Task 1 — Commit the Phase 1 baseline

**Why:** P-1. No RED/GREEN — this changes no behaviour and reaches no seam.

1. Confirm nothing secret is staged:

   ```bash
   git status --short
   git diff -- .gitignore
   ```

   Expected: the 14 modified files from `git diff --stat` above, plus untracked
   `docs/agents/lifecycle.md`, `docs/work/`, and two `.terraform.lock.hcl` files. Expected
   **absent**: any `*.tfvars`, `*.tfstate`, `tfplan`, `plan.txt`, or `*_override.tf` — all are
   gitignored, and `organization/backend_override.tf` in particular must not appear.

2. Run the available rungs against the current tree so the baseline is a passing one:

   ```bash
   ./scripts/verify.sh organization
   ```

   Expected: `terraform fmt -check -recursive` PASS, `terraform init` PASS, `terraform validate`
   PASS, `terraform plan` PASS, `no-destroy guard on shared model` PASS. The four SKIP lines
   (conftest, tflint, runtime read-back, unit tests) are expected and are not passes.

3. Stage and commit, scoped to explicit paths:

   ```bash
   git add .github .gitignore CLAUDE.md CONTEXT.md README.md docs modules organization projects
   git commit
   ```

   Commit message:

   ```
   feat: land the Phase 1 shared model and the agent workflow docs

   The core-blueprints module, the organization stack wiring, the pilot
   stack skeleton and the docs/agents set were built during Phase 1 and
   never committed. Committing them as the baseline PHASE2 branches from.

   No behaviour change in this commit: the tree is exactly what
   ./scripts/verify.sh organization passed against.
   ```

### Task 2 — Create the PHASE2 branch and worktree

**Why:** `workflow.md` §Branch patterns and §Worktree policy. No RED/GREEN.

```bash
git worktree add ../port-idp-PHASE2 -b feat/PHASE2-pilot-project-and-environments
cd ../port-idp-PHASE2
```

Expected: a new worktree at `../port-idp-PHASE2` on branch
`feat/PHASE2-pilot-project-and-environments`, with `git status --short` clean.

**Every remaining task runs from `../port-idp-PHASE2`.**

### Task 3 — Make the pilot stack initialisable

**Traces to:** none directly. It is the precondition for every plan-rung assertion in Tasks 4
and 5, because the pilot stack has never been initialised.

**RED — observed, not predicted.** Run:

```bash
cd projects/mayo-pilot && terraform init -input=false
```

Observed on 19 Aug 2026 from the main working tree:

```
Error: Failed to get existing workspaces: querying Cloud Storage failed:
Get "https://storage.googleapis.com/storage/v1/b/REPLACE-ME-mayo-port-idp-tfstate/o?...":
auth: "invalid_grant" "Bad Request"
```

`projects/mayo-pilot/backend.tf` names bucket `REPLACE-ME-mayo-port-idp-tfstate`. The bucket
`F-6` requires cannot be created because billing is disabled on GCP project
`mayo-base-462710` — the same block `organization/backend_override.tf` documents.

**GREEN — minimal correction.** Apply the pattern the organization stack already uses. Create
`projects/mayo-pilot/backend_override.tf`, which is **gitignored** by the `*_override.tf` rule
and must never be committed:

```bash
cat > backend_override.tf <<'EOF'
####################################################################
# TEMPORARY — local state override, identical in purpose to
# organization/backend_override.tf. Gitignored by the *_override.tf
# rule; never commit it.
#
# TO REMOVE, once billing is enabled and the bucket exists:
#   1. fill in the real bucket name in backend.tf
#   2. rm projects/mayo-pilot/backend_override.tf
#   3. terraform init -migrate-state
####################################################################

terraform {
  backend "local" {
    path = "../../../.tfstate-local/mayo-pilot.tfstate"
  }
}
EOF
terraform init -input=false
```

Expected: `Terraform has been successfully initialized!` and exit code 0.

Supply the variable values locally, also gitignored:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Leave the `REPLACE-ME` values in place. They are never applied and never committed; `G-11` is
what replaces them.

**Verification:**

```bash
git status --short
```

Expected: **empty**. Both `backend_override.tf` and `terraform.tfvars` are gitignored, so this
task produces no commit. That is intended — a placeholder in the repository is the thing
`FR-001` §Boundary warns about.

**Refactor while green:** none. The duplication with `organization/backend_override.tf` is the
deliberate per-stack duplication of `project-policy.md` §Protected structure 2.

### Task 4 — `FR-003`: the environment set becomes an input, and carries `cloud_project_id`

**Traces to:** `FR-003` (`P-2`, `DM-2`), slice `S2`.

**RED.** From `projects/mayo-pilot`:

```bash
terraform plan -input=false -out=tfplan
terraform show -json tfplan | jq '[.resource_changes[] | select(.type=="port_entity" and (.address|startswith("port_entity.environment"))) | {address, stage: .change.after.properties.string_props.stage, cloud_project_id: .change.after.properties.string_props.cloud_project_id}]'
```

Expected failing observation, two parts:

1. `cloud_project_id` is `null` on every planned `environment` entity. The property exists on
   the blueprint (`modules/core-blueprints/main.tf`, `"cloud_project_id"` under
   `port_blueprint.environment`) and `projects/mayo-pilot/main.tf` never sets it. `FR-003`
   requires it set on each.
2. Exactly two entities are planned, `-dev` and `-prod`, from a hardcoded `locals.environments`
   block. The set is a guess, not the stated list of running stages.

Capture both to `docs/work/PHASE2/evidence/fr-003-red.json`.

**GREEN — minimal correction.** Replace the hardcoded `locals` block in
`projects/mayo-pilot/main.tf` with a variable, so the set arrives as input:

- In `projects/mayo-pilot/variables.tf`, add after the `start_date` variable:

  ```hcl
  variable "environments" {
    description = <<-EOT
      The stages this project actually deploys to, keyed by stage. One
      entry per running stage and no others: an environment entity with
      nothing deployed to it is scored by S-1 as if it were real
      (FR-003). cloud_project_id records the GCP project this
      environment IS — not the Port project (O-7, P-11).

      Cloud is not a per-entry field here: FR-013/BD-2/P-11 make this
      pilot GCP-only, so it is hardcoded "gcp" on the resource rather
      than a knob on this variable. The blueprint's own cloud enum
      (aws/azure/gcp/on-prem) stays flexible for later clients.
    EOT
    type = map(object({
      title            = string
      stage            = string
      region           = string
      cloud_project_id = string
    }))

    validation {
      condition     = alltrue([for e in var.environments : contains(["dev", "test", "stage", "prod"], e.stage)])
      error_message = "stage must be one of: dev, test, stage, prod (DM-2, corrected by IR-4)."
    }
  }
  ```

- In `projects/mayo-pilot/main.tf`, delete the `locals { environments = { ... } }` block and
  change `for_each = local.environments` to `for_each = var.environments`, adding
  `cloud_project_id` and taking `cloud` from the object:

  ```hcl
  properties = {
    string_props = {
      "stage"            = each.value.stage
      "cloud"            = "gcp"
      "region"           = each.value.region
      "cloud_project_id" = each.value.cloud_project_id
    }
  }
  ```

  Keep the existing comment block above the resource; the `DM-2`/`IR-4` note about the four-value
  enum moves onto the variable's validation, where it now guards.

- In `projects/mayo-pilot/terraform.tfvars.example`, add — clearly marked as placeholder:

  ```hcl
  # Blocked on Mayo engineering: the list of stages that actually run,
  # with regions and GCP project IDs. One entry per running stage and no
  # others (FR-003).
  environments = {
    dev = {
      title            = "Pilot — Dev"
      stage            = "dev"
      region           = "us-central1"
      cloud_project_id = "REPLACE-ME-d"
    }
    prod = {
      title            = "Pilot — Prod"
      stage            = "prod"
      region           = "us-central1"
      cloud_project_id = "REPLACE-ME-p"
    }
  }
  ```

- Copy the same block into the local `terraform.tfvars` so the plan can run.

**Focused verification:**

```bash
terraform fmt -recursive ../..
terraform validate
terraform plan -input=false -out=tfplan
terraform show -json tfplan | jq '[.resource_changes[] | select(.type=="port_entity" and (.address|startswith("port_entity.environment"))) | {address, action: .change.actions, stage: .change.after.properties.string_props.stage, cloud_project_id: .change.after.properties.string_props.cloud_project_id}]'
```

Expected GREEN: one object per entry in `var.environments`; every `action` is `["create"]`;
every `cloud_project_id` is non-null; **no `delete` and no `replace` anywhere in the plan**.
Confirm the last explicitly:

```bash
terraform show -json tfplan | jq -e '[.resource_changes[].change.actions[]] | (index("delete") == null and index("replace") == null)'
```

Expected: `true`, exit 0.

Capture to `docs/work/PHASE2/evidence/fr-003-green.json`.

**Refactor while green:** none needed. Resist adding a default to `var.environments` — a default
would let the stack plan without the stage list, which is the over-creation failure `FR-003`
guards against.

**Commit:**

```bash
git add projects/mayo-pilot/main.tf projects/mayo-pilot/variables.tf projects/mayo-pilot/terraform.tfvars.example docs/work/PHASE2/evidence
git commit
```

```
feat(PHASE2): source the pilot's environments from input and record cloud_project_id

FR-003 requires one entity per stage that actually runs, with cloud,
region and cloud_project_id set. The stack hardcoded a dev/prod pair and
set no cloud_project_id, so the set was a guess and the GCP-versus-Port
project collision (O-7) stayed unsettled in data.

var.environments makes the set an input with no default, so the stack
cannot plan until Mayo supplies the running stages. An environment with
nothing deployed to it passes the S-1 scorecard dishonestly, so
over-creation is the failure mode guarded here, not under-creation.

Evidence: plan-diff rung. docs/work/PHASE2/evidence/fr-003-{red,green}.json.
No apply — E-READ is unreachable until a non-production organization exists.
```

### Task 5 — `FR-001` and `FR-002`: assert what the plan rung can actually prove

**Traces to:** `FR-001` (`P-1`, `DM-1`), `FR-002` (`P-1`, `DM-1`, `BS-11`), slice `S1`.

**No source change is expected.** `projects/mayo-pilot/main.tf` already sets `client`, `status`
and `tier` on the project, and already sets `teams` on the project and on nothing beneath it.
This task exists to *observe* that through the seam rather than to assert it from the source
text, which `project-policy.md` §Evidence levels forbids as evidence.

**Assertion 1 — `FR-001`, the three properties are non-empty in the plan:**

```bash
terraform show -json tfplan | jq -e '.resource_changes[] | select(.address=="port_entity.project") | .change.after.properties.string_props | (.client and .status and .tier)'
```

Expected: `true`, exit 0.

**Assertion 2 — `FR-002`, no entity beneath the project carries a team:**

```bash
terraform show -json tfplan | jq -e '[.resource_changes[] | select(.type=="port_entity" and .address!="port_entity.project") | .change.after.teams // []] | flatten | length == 0'
```

Expected: `true`, exit 0. A non-empty result is the second-writer defect of
`project-policy.md` §Risk area 2 and `BS-11`, and it is blocking.

**Assertion 3 — `FR-002`, the team is set exactly once:**

```bash
terraform show -json tfplan | jq -e '.resource_changes[] | select(.address=="port_entity.project") | .change.after.teams | length == 1'
```

Expected: `true`, exit 0.

**If any assertion returns false**, that is the RED for a correction inside this task: fix
`projects/mayo-pilot/main.tf` so it passes, re-run, and commit the fix with the same evidence
pair. If all three pass first time, there is nothing to fix and the task is a recorded
observation — which is the honest outcome and is not a reason to invent a change.

Capture all three to `docs/work/PHASE2/evidence/fr-001-002.json`.

**Commit:**

```bash
git add docs/work/PHASE2/evidence
git commit
```

```
test(PHASE2): record the plan-rung evidence for FR-001 and FR-002

Three jq assertions against terraform show -json: the project carries
client, status and tier; no entity beneath it carries a team; the team is
set exactly once. Observed through the provider's view of the remote
object, not asserted against the .tf text.

FR-002's other half — a child DISPLAYING the inherited team — is computed
by Port, never appears in a plan, and is not evidenced here.
```

### Task 6 — Run the full gate and record what was not reached

**Traces to:** `project-policy.md` §Evidence levels.

From the worktree root:

```bash
./scripts/verify.sh projects/mayo-pilot
./scripts/verify.sh organization
```

Expected for each stack: fmt PASS, init PASS, validate PASS, plan PASS, and for `organization`
the no-destroy guard PASS. Four SKIP lines are expected and none of them is a pass.

Then append a `## Evidence reached` section to this plan recording, verbatim:

- highest rung reached: **plan-diff**;
- `E-READ`, `E-COUNTER` and `E-HUMAN` **not reached for any requirement**, because no apply was
  run and the pilot is unnamed;
- `FR-002`'s inherited-ownership half unreached, with the reason;
- `conftest`/OPA, `tflint`, runtime read-back and unit tests unavailable, not skipped by choice.

**Commit:**

```
docs(PHASE2): record the evidence rungs reached and the ones that were not

Plan-diff is the ceiling. No apply was run, so no requirement in this plan
has E-READ evidence. Stated here rather than left to be inferred from the
absence of a claim.
```

---

## Sequencing and rollback

Tasks run in order; each is independently revertable.

- Tasks 1 and 2 are repository state only.
- Task 3 writes two gitignored files and can be undone with `rm backend_override.tf
  terraform.tfvars`.
- Task 4 is the only behaviour change. It is revertable with `git revert`, and because nothing
  is applied there is no Port-side state to unwind.
- Tasks 5 and 6 add documents only.

**Nothing in this plan reaches Port's stored state.** `terraform plan` reads the remote object;
it never writes. The `port-production` gate stays untouched.

## Traceability

| Task | Requirement | Slice | Evidence rung | Reached |
|---|---|---|---|---|
| 1 | — (precondition P-1) | — | fmt / validate / plan on `organization` | yes |
| 2 | — (`workflow.md` branch and worktree policy) | — | — | — |
| 3 | — (precondition for Tasks 4–5) | — | `terraform init` exit 0 | yes |
| 4 | `FR-003` | `S2` | `E-PLAN` | yes — `E-READ` half not reached |
| 5 | `FR-001`, `FR-002` | `S1` | `E-PLAN` | `FR-001` yes; `FR-002` negative half only |
| 6 | — (`project-policy.md` evidence ladder) | — | the ladder itself | reports what was not reached |

Requirements with **no task in this plan**, restated so the omission is not read as coverage:
`FR-004`, `FR-005`, `FR-006`, `FR-007`, `FR-008`, `FR-009`, `FR-010`, `FR-011`, `FR-012`,
`FR-013`, `FR-014`, `FR-015`. Reasons are in §Scope.

## What is still true after this plan is executed

The pilot team cannot see themselves in Port. No entity has been created; the catalog is
unchanged. What changes is that the pilot stack can be planned at all, the environment set is an
input rather than a guess, and `cloud_project_id` is carried so `S9` has something to reconcile
against when `PQ-17` closes.

**Phase 2's exit test is not approached by this plan and is not approachable until
Clarification 1 is decided.**

## Evidence reached

Recorded after Task 6's full gate run, 19 Aug 2026.

- **Highest rung reached: plan-diff.** `./scripts/verify.sh projects/mayo-pilot` and
  `./scripts/verify.sh organization` both pass every available rung: `terraform fmt -check
  -recursive`, `terraform init`, `terraform validate`, `terraform plan`, and — for
  `organization` — the no-destroy guard on the shared model.
- **`E-READ`, `E-COUNTER` and `E-HUMAN` were not reached for any requirement.** No `terraform
  apply` was run as part of this plan's approved tasks. (One unauthorized manual `apply` attempt
  was made outside this plan's tasks, against production, with placeholder values; both
  resources it touched — `port_integration.github` and `port_entity.project` — errored before
  creating anything, confirmed via `terraform state list` returning empty. Nothing was written
  to Port. This is not evidence for any requirement and is recorded here only so it is not
  mistaken for one.)
- **`FR-002`'s inherited-ownership half is unreached.** Resolved team ownership on a child
  entity is computed by Port and never appears in a `terraform plan`; only the negative half
  (no child carries its own `teams` property) was asserted, in Task 5.
- **`conftest`/OPA, `tflint`, runtime read-back, and unit tests are unavailable, not skipped by
  choice.** The first two are not installed; runtime read-back has no non-production
  organization to run against (`G-6`, a Phase 0 gate); there is no test harness in this
  repository.

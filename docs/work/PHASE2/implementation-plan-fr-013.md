# Implementation Plan — FR-013

Work item: **PHASE2**, requirement **FR-013** (environments sourced from Google Cloud rather
than typed). Derived from `specification.md` §FR-013 and slice `S9`, which supersedes `S2`.

## Status

**Research complete; implementation blocked on external access.** The mapping is drafted and
the one question that blocked planning is now answered. No task below has reached Port.

Branch: `feat/PHASE2-FR013-gcp-integration`, cut from `main` at `b9ee755`, carrying the two
GCP commits previously stranded on `feat/PHASE2-pull-request-blueprint`.

## The question that blocked this, and its answer

`VB-1e` established that the GCP integration is **self-hosted**, not hosted-by-Port, and left
open whether the `port_integration` Terraform resource applies to a self-hosted integration at
all. If it did not, `integration-gcp.tf` was not adjustable — it was throwaway.

**It does apply.** Two facts settle it:

1. The provider documents `installation_id` as *"The installation ID of the integration. Must
   contain only lowercase letters, numbers, and dashes (pattern: `^[a-z0-9-]+$`)"*, and its own
   worked example uses a self-chosen slug, `my-custom-integration-id`. That is not the shape of
   a Port-generated identifier.
2. A self-hosted Ocean deployment sets exactly that value as its `integration.identifier`
   parameter (Port's Helm instructions use `integration.identifier="ocean-custom"`).

So `installation_id` is **an identifier we choose and hand to the deployment**, not one Port
issues back to us.

**Correction, 20 Aug 2026.** This section originally added that GitHub was "the single
substantive difference", its `installation_id` (`154905752`) being Port-generated. **That was
wrong**, and reading the live tenant disproved it:

```
GET /v1/integration               -> installationId "github-ocean", appType "github-ocean"
GET /v1/integration/github-ocean  -> 200
GET /v1/integration/154905752     -> 404
```

`154905752` is the GitHub **App** installation ID — a GitHub-side number that is not a Port
object at all. Port keys the integration on the slug `github-ocean`. So there is no difference
between the two integrations on this point: **both** use a lowercase-dash identifier, and the
rule generalizes rather than having a GitHub exception.

This matters beyond tidiness. `terraform.tfvars` carrying `154905752` would not adopt the live
integration — it would plan a **create**, which is the "second empty integration" failure this
file warns about, and on apply the `"installationAppType" must be string` error that
`implementation-plan-fr-015.md` §P-1 attributes to a missing import. The import was not missing;
the identifier was wrong.

**The consequence, and it is the sharpest edge in this requirement:**
`var.gcp_installation_id` and the collector's `integration.identifier` must be the same string.
If they differ, `terraform import` adopts nothing and the following apply creates a second,
empty integration beside the real one — the same failure `github-integration.tf`'s header warns
about, reached by a different route.

## Three further findings, applied to the source

**1. The default-resources knob is not the one the draft named.** For a self-hosted deployment,
suppressing Ocean's own blueprints is `createPortResourcesOrigin=Empty` (Helm) or
`OCEAN__CREATE_PORT_RESOURCES_ORIGIN="Empty"` (Docker). Port's documentation explicitly says
**not** to use `initializePortResources=false` for this, naming it legacy behaviour.

This matters beyond tidiness: Ocean's published default GCP mapping creates `gcpProject` and
`gcpCloudResource` blueprints. Getting this parameter wrong means those land in the catalog and
**`FR-005` ("no integration-created blueprint exists") fails** — the same class of incident
Phase 1 already hit once, when 54 Ocean blueprints were found present and two had to be
imported and overridden.

**2. `cloud_project_id` was mapped to the wrong field.** The draft read
`.name | split("/") | last`. Cloud Asset Inventory returns a project's `.name` as the full asset
path — `//cloudresourcemanager.googleapis.com/projects/<number>` — so the last segment is the
project **number**, not the project ID. The property exists so that a human reading the
environment record knows which GCP project is meant (`O-7`, `P-11`); a bare number defeats that.
Corrected to `.display_name`, which is the field Ocean's own default mapping uses as the
project's title.

Still to confirm on the first real sync: whether `display_name` equals the project ID exactly,
or whether the ID is exposed as a separate field. Verify before widening `gcp_project_filter`.

**3. `PQ-17` is on the critical path, not adjacent to it.** Port's GCP integration reads the
**Cloud Asset Inventory API** for every resource kind. VPC Service Controls blocking that API is
therefore not an edge case for this requirement — it is the mechanism the requirement runs on.
`PQ-1` narrows correspondingly: because GCP is always self-hosted, the data flow is always
"collector pushes out"; what remains is whether the collector sits inside or outside Mayo's
VPC-SC perimeter.

Also worth recording: **live events are only available on the Terraform deployment method**, and
Port's own recommendation is Helm/scheduled for the first sync, then a switch to Terraform for
real-time. The writer-transition sequence in `integration-gcp.tf` follows that order.

## Defects found by sweeping the mapping expressions

The jq inside an integration mapping is the one part of this repository **no available rung
checks**. `terraform fmt`/`validate` see an opaque string inside `jsonencode`; `terraform plan`
shows the same string verbatim, because the provider does not evaluate jq either; and runtime
read-back is unavailable (`G-6`). A broken transform is therefore invisible from `git diff` all
the way to a production sync, where it surfaces as a failed-transform counter that reads like a
data problem.

`scripts/verify-mappings.sh` was added to close that specific gap. It extracts each expression
from the `.tf` source and runs it through `jq` against representative inputs. **It is explicitly
not evidence at the sanctioned seam** — `project-policy.md` §Evidence levels rules out
source-text assertions, and this reads source text. It sits below the ladder and is labelled as
such in its own header. 25 checks currently pass, and the harness was confirmed non-vacuous by
running the pre-fix expressions through it: 3 of 9 stage cases fail.

### Fixed — `environment.stage` aborted instead of returning "unknown"

`local.gcp_stage_jq` ended `| first | {d:"dev",...}[.] // "unknown"`. Its own comment claimed it
"returns `unknown` on no match". It did not — it **aborted**, on two separate paths:

```
$ echo '{"display_name":"iris-prod"}' | jq -r '<old expression>'
jq: error (at <stdin>:0): Cannot index object with null

$ echo '{}' | jq -r '<old expression>'
jq: error (at <stdin>:0): explode input must be a string
```

`first` yields `null` when no segment is single-character, and indexing an object with `null` is
a jq error rather than a null result, so the `// "unknown"` fallback was unreachable. Separately,
a project asset with no `display_name` at all failed inside `ascii_downcase`.

Plausible real project names hit this. `iris-prod` — no single-character segment — is exactly the
shape a Mayo project might carry. Binding `first` to `$seg` and defaulting it *before* the index,
plus `.display_name // ""`, makes the documented behaviour actually occur.

### Fixed — `service.language` produced values outside its own enum

`github-integration.tf` mapped `language = ".language // \"other\" | ascii_downcase"`, handing
GitHub's language name straight to a closed enum:

| GitHub returns | Old expression gives | In `service.language` enum? |
|---|---|---|
| `TypeScript` | `typescript` | yes |
| `C#` | `c#` | **no** |
| `C++` | `c++` | **no** |
| `Rust` | `rust` | **no** |

The enum permits `typescript`, `javascript`, `python`, `php`, `go`, `java`, `csharp`, `other`.
**`FR-008` requires the first sync's failed counter to be zero**, so a single C# or Rust
repository in the pilot made that acceptance criterion unreachable — and it would have presented
as bad data rather than as a mapping bug. Replaced with an explicit lookup that degrades anything
unlisted to `other`, a value the enum actually has.

This is outside FR-013's own scope. It is fixed here rather than filed because it is a two-line
correction in a file this branch already touches, and leaving a known-broken enum mapping in
place to respect a work-item boundary would be the wrong trade.

### Swept and clean

`pull_request.status`, `pull_request.identifier`, and `environment.region` were checked against
null, missing-key, and unexpected-value inputs. None errors and none produces a value outside its
blueprint's enum. `region` correctly yields `unknown` when `.labels` is absent or null.

## Findings NOT fixed — each needs a decision, not a patch

**1. `deleteDependentEntities = true` contradicts `N-3`.** Both mappings set it. The `repository`
blueprint's own comment warns that deletion "destroys history, including AI spend records finance
may still need for a closed quarter, and Port's cascade can remove related records without
warning" — and this flag is what enables that cascade. Flipping it changes deletion behaviour on
a live integration, so it belongs to `FR-004`'s review with a named decision, not to a drive-by
edit on this branch.

**2. `N-3`'s archived-to-deprecated rule is not implemented anywhere.** The `repository` blueprint
documents "archived repositories are marked deprecated, never deleted", but the GitHub mapping
never reads `.archived` and hardcodes `lifecycle = "experimental"`. Implementing it would collide
with `FR-009` as written ("every ingested service arrives `experimental`"), so this is a
specification tension for the sponsor, not a bug with an obvious fix. Related to the `DM-5` gap
already recorded in `ADR-002`.

## Scope

**In scope:** correcting `integration-gcp.tf` and its variables against the findings above, and
recording the deployment sequence. Done, in this branch.

**Explicitly out of scope, with the reason:**

| Left out | Reason |
|---|---|
| Deploying the collector | Needs Google Cloud read access (`PQ-17`) and a decision on where it runs relative to the VPC-SC perimeter (`PQ-1`). Neither is ours to close. |
| `terraform import port_integration.gcp` | Nothing to import until the collector is deployed and registered. |
| Any `terraform apply` | Gated by the `port-production` environment with required reviewers (`project-policy.md` §External authority). |
| Confirming the stage-derivation expression | `local.gcp_stage_jq` is a placeholder against the IRIS `d`/`t`/`s`/`p` convention. It cannot be validated without real Mayo project names. |
| Cloud Run, GKE, Cloud Functions kinds | They map onto a `workload` blueprint that does not exist yet (`BS-13`, Phase 4). Adding a kind before its blueprint produces failed-transform counters, not data. |
| Removing the hand-declared `port_entity.environment` blocks | That is step 5 of the writer transition and must not happen before step 1 succeeds. Doing it early leaves the pilot with no environments at all. |

## Evidence reached

**Formatting and validity rungs pass on both stacks. The plan rung was NOT run — no Port
credential was available to this session. Say so in any completion claim; `E-PLAN` is not
claimed here.**

Terraform 1.15.8 was installed for this work, pinned deliberately to the version
`plan.yml` and `apply.yml` both set, so these results correspond to what CI would produce.

### Rungs run

| Rung | Command | Result |
|---|---|---|
| Formatting | `terraform fmt -check -recursive .` | **PASS**, exit 0, repository-wide |
| Validity | `terraform init -backend=false` + `terraform validate`, `organization` | **PASS** — "Success! The configuration is valid." |
| Validity | same, `projects/mayo-pilot` | **PASS** — "Success! The configuration is valid." |
| Plan-diff | `terraform plan`, `organization` | **RUN** — `0 to add, 1 to change, 0 to destroy` |
| Plan-diff | `terraform plan`, `projects/mayo-pilot` | **RUN** — `4 to add, 1 to change, 0 to destroy` |

The plan rung was reached on 20 Aug 2026 against the live sandbox tenant, credentials supplied
by the user. **Reads and plans only. No `apply` was run.**

State does not exist on this machine — the GCS bucket is still `REPLACE-ME-mayo-port-idp-tfstate`
— so both stacks got a gitignored local `backend_override.tf` with state under `/tmp`, and the
live objects were adopted with `terraform import`, which reads the remote object and writes only
local state. Without that step the plan reports everything as a create and is worthless as a
diff.

```
organization                            mayo-pilot
  update module.core_blueprints           create port_entity.environment["dev"]
         .port_blueprint.repository       create port_entity.environment["prod"]
                                          create port_entity.project
                                          create port_integration.gcp
                                          update port_integration.github
```

**Zero deletes and zero replaces in both plans** — the `organization` destroy-guard passes.

### What the live tenant actually contains

| Question | Answer |
|---|---|
| Do the 10 shared blueprints exist? | **Yes, all 10** — including `pull_request` |
| How many entities on them? | **Zero, on every one** |
| Integrations installed | exactly one: `github-ocean`, Ocean v6.8.1 |
| Teams | `default-team`, `default-group` — both with a **null identifier** |
| Total blueprints in tenant | **62** |

**`FR-005` is already failing, and by a wide margin.** Its criterion is that no
integration-created blueprint exists in the catalog. **37 do** — `githubRepository`,
`githubPullRequest`, `githubWorkflow`, plus whole families from Azure DevOps, Datadog, New Relic,
Jira and AWS. The GCP mapping's `createPortResourcesOrigin=Empty` correction prevents this
getting worse; it does nothing about the 37 already there. Cleaning them up is its own work item
and needs a decision, because some may now have entities.

### The single most important finding: do not apply `mayo-pilot`

The plan for `port_integration.github` is an **update that removes live configuration**:

- `installation_app_type = "github-ocean" -> null`. The resource does not declare the field, and
  this provider blanks what a resource does not declare. That is risk area 1 in
  `project-policy.md`, reproduced here in an actual plan rather than in the abstract.
- The live integration carries a **richer `pull-request` mapping than the committed code** —
  `states = ["closed"]`, `since = 90`, `maxResults = 300`, a selector of
  `.base.ref == "main" and .state == "closed" and .merged_at != null`, and a
  `"Merge: " + .title` title. The committed mapping filters `states = ["open"]` and would
  **delete all of that**.

Someone configured merged-PR ingestion in the UI. `github-integration.tf` explicitly defers
merged history to Phase 4 pending `G-9`, and its `repoManagedMapping = false` comment warns that
two sources of mapping truth is the same failure mode as UI-plus-Terraform. **That failure has
already happened in this tenant.** Which mapping is correct is a decision for whoever made the
UI change, not something to resolve by applying.

### The mapping expressions, verified at the plan rung

Both corrected expressions were extracted from `terraform show -json tfplan` — the exact JSON
Terraform will send to Port — and executed under `jq`:

```
language  (.language // "other" | ascii_downcase) as $l | {...}[$l] // "other"
          C# -> csharp    C++ -> other    Go -> go    {} -> other

stage     (.display_name // "" | ... | first) as $seg | {...}[$seg // ""] // "unknown"
          iris-d-app -> dev    iris-prod -> unknown    {} -> unknown
```

That closes the chain end to end: source → HCL render → `jsonencode` → plan JSON → executed jq.
It still is not proof that Ocean evaluates them identically at sync time, which remains
unreachable until the collector runs.

### Transform-logic checks, below the ladder

- `./scripts/verify-mappings.sh` — 25 checks pass. Labelled in its own header as **not** seam
  evidence, because `project-policy.md` §Evidence levels rules out source-text assertions.
- **Vacuity check:** the pre-fix expressions were run through the same assertions. 3 of the 9
  stage cases fail, on two distinct jq errors. A check that cannot fail proves nothing.
- **Round-trip through Terraform's own renderer.** `terraform console` was used to evaluate
  `local.gcp_stage_jq` and the composed environment identifier, and the *rendered* strings — not
  a hand-unescaped approximation of them — were executed under `jq`. Both behave as intended
  across all nine inputs, and `$seg` survives HCL rendering without being mistaken for
  interpolation. This is the closest reachable approximation of the real transform without a live
  sync.

### The plan rung, and who can run it

`terraform plan` needs `PORT_CLIENT_ID` / `PORT_CLIENT_SECRET`, which were unset in this session.
Per the standing convention recorded in `handoff.md`, credentialed commands are run by the user
rather than by an agent, so this is handed over rather than attempted:

```bash
export PORT_CLIENT_ID=...
export PORT_CLIENT_SECRET=...
./scripts/verify.sh projects/mayo-pilot
./scripts/verify.sh organization
```

`projects/mayo-pilot` needs a gitignored `backend_override.tf` pointing at a local backend, per
`implementation-plan.md` Task 3, because the GCS bucket is still blocked on billing. One was
created during this session with its state path under `/tmp`, and is ignored by the
`*_override.tf` rule.

It also needs a `terraform.tfvars`. `var.environments`, `var.gcp_installation_id` and
`var.gcp_project_filter` have no defaults by design, so the stack cannot plan until real values
exist — which is `FR-003`'s guard working as intended, not an obstacle to remove.

**What a plan can and cannot prove here.** It will confirm the mapping config Terraform intends
to send, and that no destroy or replace is present. It will **not** evaluate the jq — the provider
does not either. Only a live resync does, which is why the pre-flight harness exists.

`E-READ` for `FR-013` — the `environment` list compared against the GCP project inventory — is
not reachable until the collector runs.

### Provider lock files completed

`terraform init` on Linux revealed that both `.terraform.lock.hcl` files carried **only macOS
hashes**, because Phase 1 was developed on a Mac. Terraform still verified successfully against
the registry `zh:` hashes and then appended the missing `linux_amd64` `h1:` hash — so CI was not
broken, but every run on a different platform from the last committer's produced a spurious lock
diff, and a workflow that checks for a clean tree would trip on it.

Completed with `terraform providers lock -platform=linux_amd64 -platform=darwin_amd64
-platform=darwin_arm64`, covering CI plus both Mac architectures. Confirmed stable: a subsequent
`init` on both stacks produces no further lock change.

## Remaining tasks, in dependency order

| # | Task | Owner | Blocked on |
|---|---|---|---|
| 1 | Run the **plan** rung and record the output — `fmt` and `validate` are already done and recorded above | whoever holds the Port credential | a Port credential; a real `terraform.tfvars` |
| 2 | Close `PQ-1` — decide whether the collector runs inside or outside the VPC-SC perimeter | Mayo cloud + platform | nothing but a decision |
| 3 | Close `PQ-17` — confirm the collector can reach the Cloud Asset Inventory API | Mayo cloud | task 2 |
| 4 | Obtain viewer-level read per pilot GCP project, never folder or org (`BS-14`) | Mayo cloud | task 3 |
| 5 | Get the real pilot project names; validate or rewrite `local.gcp_stage_jq` | Mayo engineering | task 4 |
| 6 | Choose the integration identifier; deploy via Helm with `createPortResourcesOrigin=Empty` | platform | tasks 4, 5 |
| 7 | Confirm no `gcp*` blueprint appeared — `FR-005` still passes | platform | task 6 |
| 8 | Confirm `display_name` is the project ID against raw sync data | platform | task 6 |
| 9 | `terraform import port_integration.gcp <identifier>`, then plan clean | platform | task 6 |
| 10 | Execute the writer transition, steps 3–6 in `integration-gcp.tf` | platform | task 9 |

Tasks 2 through 5 are **not engineering work** — they are access and information requests. FR-013
cannot advance past task 1 without them.

## Rollback

Everything in this branch is comments, variable documentation, and two string values. Nothing is
applied and nothing reaches Port's stored state, so `git revert` is a complete rollback. The
writer transition (task 10) is the first step with a Port-side consequence, and step 4 of it
deliberately uses `terraform state rm` rather than a destroy, so the existing entities are
orphaned rather than deleted.

## What is still true after this plan

The pilot's environments are still hand-typed. What changes is that the file which will replace
them is no longer built on an unverified assumption, the `FR-005` trap in the deployment
parameters is documented before anyone trips it, and the `cloud_project_id` mapping would have
stored a project number instead of a project ID.

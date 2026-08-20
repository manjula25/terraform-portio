# FR-005 — removing the Ocean default blueprints

Work item: **PHASE2**, requirement **FR-005** (no integration-created blueprint exists in the
catalog). Written 20 Aug 2026.

## Status

**Done. FR-005 passes.** Executed 20 Aug 2026 against the production tenant. The blueprint list
went from **62 to 21**: our 10, plus the 11 Port system blueprints, and nothing else. 41 Ocean
default blueprints and their 33 entities are gone.

Verified by reading `GET /v1/blueprints` back, independently of the script's own assertion —
`evidence/fr-005-green.json`. This is the `E-READ` evidence the requirement asks for.

## What FR-005 requires

From `specification.md`:

> the organization's blueprint list contains no integration-created type — specifically no
> second service-shaped blueprint and no integration-created repository or pull-request type —
> and every blueprint present is declared in `modules/`.

Its boundary note is worth quoting too, because it predicted exactly this state:

> **This has already gone wrong once in this tenant.** Phase 1 found 54 provisioned default
> blueprints in the working organization, including a rival `service`, and had to import and
> override two of them.

## Measured state

Read from `GET /v1/blueprints` on 20 Aug 2026:

| Group | Count | Disposition |
|---|---|---|
| Declared in `modules/core-blueprints/` | 10 | keep |
| Port system (leading underscore) | 11 | never touch |
| **Ocean default resources** | **41** | **delete** |
| Total in tenant | 62 | |

The 41 span five integrations, only one of which is actually installed: `azureDevops*` (14),
`datadog*` (7), `newRelic*` (5), `jira*` (3), `github*` (7), plus `awsAccount`, `cloudResource`,
`deployment`, `organization`, `workload`. There is no Azure DevOps, Datadog, New Relic, Jira or
AWS integration in this tenant — only their leftover schema, which is why the Port sidebar shows
pages for products nobody connected.

Note `organization` and `deployment` carry no vendor prefix but are **not** ours: neither appears
in `modules/core-blueprints/main.tf`. Identifying candidates by prefix would have missed both.

### Entities that go with them

33 in total, all orphaned by the ADR-003 mapping convergence earlier the same day — nothing
writes them any more:

| Blueprint | Entities |
|---|---|
| `githubRepository` | 25 |
| `githubWorkflow` | 2 |
| `githubWorkflowRun` | 2 |
| `githubOrganization`, `githubPullRequest`, `githubUser`, `organization` | 1 each |

The other 34 candidates hold zero.

## Why a script rather than Terraform

`terraform destroy` cannot reach these. Nothing in this repository declares them — Ocean created
them at integration install time, which is the whole substance of the FR-005 violation. Removing
them is a one-off tenant repair, not configuration, so the script lives in `scripts/` and is
deliberately **not** wired into `verify.sh`.

## Why deletion is safe, established before writing the script

The dependency direction was checked in both directions, via `GET /v1/blueprints/<id>` on all 51
non-system blueprints:

- **None of our 10 relates to any of the 41.** Every relation target among our blueprints is
  either another of ours (`project`, `service`, `environment`, `agent`, `ingestion_source`) or a
  Port system blueprint (`_team`).
- **Nine of the 41 relate to ours** — `deployment -> service`, `jiraIssue -> service`,
  `workload -> service`, `workload -> environment`, `cloudResource -> environment`,
  `azureDevopsBuild -> service`, `azureDevopsPullRequest -> service`,
  `githubPullRequest -> service`, `githubWorkflowRun -> service`.

So the dependency arrows point *inward at* the shared model, never out of it. Deleting the 41
removes inbound relations only, which is the intent — those relations are how Ocean's parallel
model was quietly attaching itself to ours.

The 41 also relate to **each other** (69 edges; `azureDevopsProject` is depended on by 10).
Port refuses to delete a blueprint another still targets, so the script deletes in repeated
passes, taking whatever has become a leaf each time, and stops when a pass makes no progress.
That mechanism worked: `azureDevopsPipelineRun`, `azureDevopsPipelineStage`, and three
`newRelic*` blueprints failed on pass 1 and succeeded on pass 2.

### Correction — Port does not cascade entity deletion

The first run assumed deleting a blueprint would take its entities with it. **It does not.**
34 of 41 were removed and exactly the seven holding entities refused, each with:

```
This Blueprint cannot be deleted because there are existing "<identifier>" entities
```

The script now empties each candidate first —
`DELETE /v1/blueprints/<bp>/entities/<id>?delete_dependents=true` — and only then deletes the
blueprint. The second run removed all 33 entities and all seven remaining blueprints on a single
pass. Two runs were needed only because the first taught us this; a fresh tenant would take one.

## Safety properties of the script

1. **Three-way classification.** System blueprints (`_*`) are never candidates. Ours are never
   candidates. Everything else is.
2. **`OURS` is derived, not hardcoded** — from `terraform state list` cross-referenced against
   the `identifier` values in `modules/core-blueprints/main.tf`. It cannot drift from what the
   repository actually owns, and if the derivation yields nothing the script refuses to run
   rather than treating every blueprint as deletable.
3. **Entity counts are reported per blueprint, and totalled, before anything is deleted.**
   The entities are deleted first, explicitly — see the correction below.
4. **Dry run is the default.** `--apply` is required to delete.
5. **It asserts FR-005 itself** afterwards, re-reading `GET /v1/blueprints` and exiting non-zero
   if any undeclared blueprint remains.

## Running it

```
set -a && . ./.env && set +a
./scripts/prune-ocean-blueprints.sh            # review
./scripts/prune-ocean-blueprints.sh --apply    # delete
```

Prints `PASS  only declared blueprints remain` when FR-005 is satisfied.

## Before running it

**Capture the definitions first.** Blueprint deletion is irreversible. These 41 are all
reproducible Ocean defaults, so the loss is recoverable in principle, but the record costs
nothing:

```
curl -s "$PORT_BASE_URL/v1/blueprints" \
  -H "Authorization: Bearer $TOKEN" \
  > docs/work/PHASE2/evidence/fr-005-pre-prune-backup.json
```

Both backups **were** taken before this prune ran:

- `evidence/fr-005-pre-prune-backup.json` — all 62 blueprints with full schemas and relations,
  verified to contain every one of the 41 deleted.
- `evidence/fr-005-pre-prune-entities.json` — the 33 deleted entities, by blueprint, with their
  identifiers.

## Evidence

`E-READ`, captured at the sanctioned seam — the blueprint list as Port returns it, not the source
text:

| File | What it holds |
|---|---|
| `evidence/fr-005-green.json` | the list after: 21 total, 10 declared, 11 system, **0 undeclared** |
| `evidence/fr-005-pre-prune-backup.json` | all 62 before, with full schemas |
| `evidence/fr-005-pre-prune-entities.json` | the 33 entities deleted |

The GREEN file was built from an independent `GET /v1/blueprints` after the run, not from the
script's own exit status. `./scripts/verify.sh` passes every available rung on both stacks
afterwards, and the `organization` plan shows no drift — deleting undeclared blueprints did not
disturb the ten Terraform owns.

## Observed after the run

- The Port sidebar loses the Jira, Datadog, New Relic, Azure DevOps and leftover GitHub pages.
- 33 orphaned entities are gone, including the 25 `githubRepository` records.
- `FR-005` passes, and the Phase 1 incident it was written against is closed out.
- Our own entities are untouched: `project` 1, `environment` 2, and the integration mapping still
  reads `blocks=2`, `installationAppType=github-ocean`.
- `service` and `pull_request` are still 0 — unrelated to this work. They await a UI **Resync**;
  see `implementation-plan-fr-013.md`.
- Re-running the Ocean installer with default resources enabled recreates all of them. The
  guard is `createPortResourcesOrigin=Empty` at install — documented in `integration-gcp.tf`
  step 1 for the GCP collector, and the same trap applies to any future integration.

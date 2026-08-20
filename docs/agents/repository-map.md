# Repository Map

Provide navigation pointers to authoritative source; do not narrate implementation behavior.

## Entry points

- `organization/main.tf` — the shared model, applied once by the platform team
- `projects/mayo-pilot/main.tf` — the pilot stack
- `README.md` — first-time setup, in order

## Packages or modules

- `modules/core-blueprints/` — `project`, `environment`, `service`, `ai_usage`. Carries TODOs for blueprints the PRD already specifies; the code lags the spec
- `modules/scorecards/` — README only, not written
- `modules/actions/` — README only, not written
- `modules/ai-usage-ingestion/` — README only, not written. Will hold Python, not Terraform

## Public interfaces

Per `docs/agents/project-policy.md`, the public seam is Port's API view of a managed object, not the source text.

- `modules/core-blueprints/outputs.tf` — what project stacks may consume from the shared model
- `modules/core-blueprints/versions.tf` — the provider pin
- `projects/mayo-pilot/variables.tf` and `terraform.tfvars.example` — the per-project input contract

## Persistence boundaries

- `organization/backend.tf` and `projects/mayo-pilot/backend.tf` — separate GCS state per stack. Duplication is deliberate; see `docs/adr/ADR-001-per-stack-provider-and-state.md`
- Port itself holds every entity. This repository holds no data of its own
- No secret is stored in either state file; credentials arrive from the environment

## Integrations

- `projects/mayo-pilot/github-integration.tf` — the GitHub (Ocean) mapping
- `docs/github-ocean-setup.md` — installation, including the non-optional `terraform import` step

## Tests

None. There is no test harness in this repository, by current state rather than by intent. `docs/agents/project-policy.md` defines the evidence ladder that stands in for one, and names which rungs are unavailable.

## Build and deployment configuration

- `.github/workflows/plan.yml` — every pull request. Plans each affected stack, replans all project stacks when `modules/` changes, comments the plan, and fails the `organization` plan if it contains a delete
- `.github/workflows/apply.yml` — merge to `main`, gated by the `port-production` GitHub environment
- `scripts/verify.sh` — the local equivalent of the plan gate, reporting each rung's exit code
- `scripts/verify-mappings.sh` — runs each integration mapping's `jq` against sample inputs. A pre-flight check that reads source text, so explicitly **below** the evidence ladder, not a rung
- `scripts/prune-ocean-blueprints.sh` — deletes the Ocean default-resource blueprints that make `FR-005` fail. Not configuration and not part of `verify.sh`: nothing in this repository declares those blueprints, so no `terraform destroy` can reach them. Dry run by default; `--apply` deletes
- `scripts/restore-ocean-blueprints.sh` — the rollback for the above, recreating all 41 from `evidence/fr-005-pre-prune-backup.json`. Restores **schema only**; the deleted entities are catalog data and do not come back. Running it makes `FR-005` fail again, by design
- `.gitignore` — keeps state, plan files, and `.tfvars` out of the repository

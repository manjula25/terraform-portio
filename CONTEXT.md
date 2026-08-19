# Project Context

## Purpose

This repository **is** the Port.io configuration for Mayo, expressed as Terraform. Port is a bought SaaS product; what is built here is the data model, the integration mappings, the action backends, the interface configuration, and one genuinely custom program (the AI-usage ingestion pipeline). If a blueprint, scorecard, action, permission, page, or entity is not in this repository, it does not exist — see invariant 3.

The design that produced it lives one directory up, outside this repository. `../mayo-port-prd.md` is the authoritative specification and wins on any conflict; `../mayo-port-build-spec.md` is its implementation companion. See `docs/agents/domain.md` for the full authority order.

## Actors

| Actor | Interacts how |
|---|---|
| Platform team | Owns `modules/` and `organization/`. The only role that can change the shared model |
| Project leads | Own one `projects/<name>/` stack. Cannot merge changes to `modules/` |
| Developers at Mayo | Read the catalog, run self-service actions, claim agents. Never edit this repository |
| Leadership and Finance | Read cost and adoption views. Never edit |
| Port.io (SaaS) | The system this repository configures, through its API |
| GitHub (Ocean) integration | Writes `service` and `repository` records into Port. Not managed from here beyond its mapping |
| Google Cloud integration | Writes `environment` and later `workload` records |
| The ingestion pipeline | Writes `ai_usage`, `agent`, and `ingestion_source` records |
| SailPoint | Owns access approval and provisioning. Port reflects its status and never writes entitlements |
| Entra ID | Supplies teams at sign-in and removes users through SCIM |

## Glossary

| Term | Meaning here |
|---|---|
| **Blueprint** | A Port entity type — a schema. Owned by Terraform, always |
| **Entity** | One record of a blueprint. Ownership varies by type; see the writer table |
| **Stack** | One directory with its own state: `organization/`, or one `projects/<name>/` |
| **Writer table** | The single-owner-per-record-type table in `../mayo-port-build-spec.md` §1.3. Two writers on one record type is a bug |
| **Create-and-override** | The Port Terraform provider resets any property a resource does not declare to empty on apply. The reason single ownership is not a style preference |
| **Port project** | A client engagement — the tenancy boundary. **Not** a GCP project, which is a resource container |
| **Port organization** | A tenant under the Port account, used here as dev versus production. **Not** the `environment` blueprint |
| **`actor_type`** | `developer_seat`, `agent`, or `application`. Three different cost stories; never summed |
| **Skill / MCP server** | Registry records of an approved AI capability. **Not** a human competency, and not this repository's own agent skills |
| **Shadow agent** | An agent with spend and no claimed owner |
| **Ocean** | Port's integration framework. The current GitHub integration; the legacy GitHub app is deprecated from 2026-09-15 |

## Workflows

1. **Change the shared model.** Edit `modules/core-blueprints/`, open a PR, read the plan comment for every project stack the change touches, merge, apply. A shared-module change replans every project by design, because that blast radius is the review artifact.
2. **Onboard a project.** Copy a `projects/<name>/` directory, fill its variables, apply. Never edit `modules/` to accommodate one project.
3. **Adopt an integration.** Install it in Port, then `terraform import` the mapping before the first apply. Skipping the import blanks the mapping the integration wrote.
4. **Ingest AI usage.** The pipeline reads each provider, prices tokens against a versioned rate card, upserts `ai_usage` idempotently on `provider + actor_ref + period_start`, and records per-source freshness.
5. **Claim an agent.** The pipeline auto-creates an agent record on first observed spend, flagged unregistered; a human claims ownership through an action.

## Development lifecycle

Work moves through the skills in `.claude/skills/engineering/`. `docs/agents/workflow.md`
holds the operational detail — branch names, commands, worktree policy, review topology.
This is the map of which skill owns which step and what each one is allowed to assume.

| Step | Skill | Produces | Owns the question |
|---|---|---|---|
| 1 | `work-item-context` | `docs/work/{ID}/context.md` | What is this one requirement, and where does it come from? |
| 2 | `grilling` / `grill-with-docs` | pressure-tested assumptions | What are we wrong about before it costs anything? |
| 3 | `domain-modeling` | glossary and ADR entries | What do these words mean, and which invariant governs them? |
| 4 | `to-prd` | `docs/work/{ID}/prd.md` | What are we building and why? **Normally skipped — see below** |
| 5 | `to-slices` | `docs/work/{ID}/slices.md` | What is the smallest thing we can demonstrate end to end? |
| 6 | `to-spec` | `docs/work/{ID}/specification.md` | What does "correct" mean, measurably? |
| 7 | `to-tickets` | `docs/work/{ID}/tickets/*.md` | What order does the work unblock in? |
| 8 | `codebase-design` | module interfaces and seams | Where does this cut into the repository? |
| 9 | `writing-plans` | `docs/work/{ID}/implementation-plan.md` | Which exact files, commands, and expected results? |
| 10 | `using-git-worktrees` | an isolated branch and worktree | Where does this change happen without touching the shared tree? |
| 11 | `implement` | one accepted candidate | Build it, one slice at a time, RED before GREEN |
| 12 | `tdd` | the RED-to-GREEN cycle inside a slice | Did the test fail first, for the stated reason? |
| 13 | `ponytail` | simplification findings | What complexity can be removed before review? |
| 14 | `code-review` | review findings | Does it meet the standard and the spec? |
| 15 | `verification-before-completion` | `docs/work/{ID}/verification.md` | What was actually run, and what does the output say? |
| 16 | `finishing-a-development-branch` | a merged branch | Is it landed and cleaned up? |
| 17 | `handoff` | a handoff note | What does the next person need that is not in the code? |

Supporting skills, used when the situation calls for them rather than in sequence:
`diagnosing-bugs` for a defect that needs a root cause before a fix,
`improve-codebase-architecture` for structural debt, and
`setup-agentic-workflow` for re-provisioning this configuration itself.

### The standing shortened flow

Steps 1 through 4 are **normally skipped in this repository**, and that is the rule
rather than an exception. `../mayo-port-prd.md` is already an approved specification
with numbered requirements and checkable "Done when" lines, and
`../mayo-port-build-spec.md` is its implementation companion. Re-deriving requirements
here would duplicate them and create an authority conflict with the authority order in
`docs/agents/domain.md`.

So the normal entry point is `work-item-context` capturing **one requirement or one
phase**, citing the PRD as its source and quoting the "Done when" line as supplied
acceptance criteria — then straight to `to-slices`.

Run the full front end only for something the PRD does not cover. If discovery
contradicts the PRD, that is a PRD amendment with its own decision. It is not a local
override, and it is not something to settle inside a work item.

### Terraform changes the meaning of a slice

Two adaptations, because this repository configures a SaaS product rather than
building an application:

- **A slice is demonstrable in Port, not in a test suite.** There is no unit-test
  runner here (`docs/agents/workflow.md` lists what is deliberately absent). `tdd`'s
  RED-to-GREEN maps onto `terraform plan`: the expected failing observation is a plan
  that does not yet contain the resource, and GREEN is the plan or apply that does.
  A slice whose only evidence is "the file parses" is not demonstrable.
- **`implement` must respect create-and-override.** A slice that touches a blueprint
  another writer owns is not a code change, it is a data migration. Check the writer
  table in `../mayo-port-build-spec.md` §1.3 before planning one, and back up the live
  blueprint and its entities first.

## Invariants

1. **Metadata only.** Names, links, counts, dollars. Never PHI, never secrets, never AI prompt or completion content. Concretely: `includedFiles` is never set in an integration mapping. Crossing this puts Port inside the PHI boundary and reopens the entire compliance posture.
2. **Port is not an access system of record.** SailPoint owns approval, provisioning, and certification. No action in this repository writes an entitlement.
3. **Config as code, always.** The UI is for throwaway exploration, including the leadership dashboards.
4. **One writer per record type.** Enforced by the writer table, required by create-and-override.
5. **One model, many projects.** Per-project differences live in entities, scorecard rules, and permissions — never in a forked blueprint.
6. **Never aggregate across `actor_type`.** Adding what we spend building software to what our software spends running produces a number that means nothing.
7. **Null and zero are different claims.** A missing source is not "spent nothing", and no view may render stale data as current.
8. **Secrets never enter Terraform state.** Port credentials arrive as `PORT_CLIENT_ID` / `PORT_CLIENT_SECRET` in the environment, never as Terraform variables. Provider org keys live in GCP Secret Manager and are read at runtime by the pipeline only.

## External boundaries

Port.io's API and its own permission model; GitHub and Azure DevOps; Google Cloud (state bucket, Secret Manager, project inventory); Jira and Confluence, linked only and never ingested; Microsoft Teams for notifications; Entra ID for identity; SailPoint for entitlement; Anthropic, OpenAI, Vertex AI, and Azure OpenAI usage APIs.

## Unresolved domain questions

Tracked as `PQ-*` in `../prd-open-questions.md`, which is the authoritative list. The ones that change what this repository can contain:

- Which git provider the pilot actually uses — the estate shows both GitHub and Azure DevOps (`PQ-6` and the `improved/iris-findings-plan-delta.md` findings).
- Whether the Port account permits a non-production organization, and at what cost. Until it does, no change can be proven by applying it anywhere but production.
- Whether Port runs on the US or EU instance, which also decides data residency.
- Whether Entra groups match real delivery squads. If they do not, per-team rollups reflect the org chart rather than the teams doing the work.
- What "permission" means on the `skill` and `mcp_server` registries, given that registries show and never enforce.

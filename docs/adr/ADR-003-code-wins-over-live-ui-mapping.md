# ADR-003: Terraform wins over the live UI mapping, and Ocean's default resources are discarded

- **Status:** Accepted
- **Date:** 2026-08-20
- **Owners:** manjula

## Context

The live Port tenant's GitHub integration and this repository's `github-integration.tf` had
diverged, and the divergence was not visible in any diff. It was found at the plan rung, by
reading `terraform show -json tfplan` for the `mayo-pilot` stack.

**Live** (`.change.before.config`) carried ten mapping blocks, all of them Ocean
default-resource output:

| Kind | Target blueprint |
|---|---|
| `organization` | `githubOrganization` |
| `team` | `githubTeam` |
| `user` | `githubUser` |
| `repository` | `githubRepository` |
| `team` | `githubUser` |
| `pull-request` | `githubPullRequest` |
| `workflow` | `githubWorkflow` |
| `workflow-run` | `githubWorkflowRun` (×2, one to `githubWorkflow`) |
| `pull-request` | `deployment` |

**Committed** carried two: `repository -> service` and `pull-request -> pull_request`.

None of those ten target blueprints is one of the nine in `modules/core-blueprints/main.tf`.
Two of them were failing in the tenant, reported in the Port UI as *"filter on non exists
properties is not supported"* against `terraform-portio-deploy-1` and
`terraform-portio-pr-1`. The cause is in the mappings themselves: both the
`workflow-run -> githubWorkflowRun` and `pull-request -> deployment` blocks resolve their
`service` relation by searching the property `github_repository_id`, and **no blueprint in this
model defines that property** (`grep -rn github_repository_id modules/ organization/` finds
nothing). The mapping could not have worked against this catalog in any configuration.

So the tenant was in the state `FR-005` ("no integration-created blueprint exists") exists to
forbid: default resources were created at install time and never removed. This is the same
class of incident Phase 1 already hit once, when 54 Ocean blueprints were found present.

## Decision

**Terraform is the sole writer of the integration mapping, and the live UI mapping is
discarded rather than merged.** Concretely:

1. The two committed mapping blocks stay as they are. Applying `mayo-pilot` collapses the live
   ten to those two, deliberately.
2. The richer live `pull-request` block — `states ["closed"]`, `since 90`, `maxResults 300`,
   selector `.base.ref == "main" and .state == "closed" and .merged_at != null` — is **not**
   adopted. The reasoning is recorded inline in `github-integration.tf` beside the block it
   would have modified.
3. Ocean's default blueprints are to be deleted from the tenant, not accommodated by adding
   `github_repository_id` to the shared model.
4. `deleteDependentEntities = false` on both integrations, so this convergence orphans entities
   visibly instead of destroying them.

## Alternatives considered

- **Add `github_repository_id` to the `service` blueprint so the live mappings resolve.**
  Rejected, and it is the tempting option because it turns two red rows in the UI green. It
  fails rule 5 ("one model, many projects") and `T-1`: the property names a git vendor, in the
  shared model, to satisfy a mapping this repository did not write and does not want. It also
  ratifies `deployment` and `githubWorkflowRun` as part of the catalog by making them work.

- **Adopt the live `pull-request -> deployment` block into code.** Rejected on four grounds,
  any one of which is sufficient: `deployment` is not in the shared model, so adopting it means
  adopting a blueprint `FR-005` forbids; `states ["closed"]` + `since 90` is exactly the
  unbounded merged history the `G-9` gate holds back; the block's `service` relation is broken
  as described above; and nothing in the specification asks for it.

- **Merge the two mappings — keep ours, append the live blocks that do not conflict.**
  Rejected: it produces two writers for `pull-request` (risk area 2) and leaves the catalog
  split across `service` and `githubRepository` for one GitHub kind.

- **Reverse the direction — treat the tenant as truth and import the live mapping into code.**
  Rejected as the one option that contradicts the repository's purpose. It would make the UI
  the source of mapping truth, which rule 3 and this file's whole premise deny.

## Consequences

- **The apply that converges this is destructive to catalog data**, and that is the point worth
  stating plainly: entities under `githubOrganization`, `githubTeam`, `githubUser`,
  `githubRepository`, `githubPullRequest`, `githubWorkflow`, `githubWorkflowRun` and
  `deployment` stop being written. With `deleteDependentEntities = false` they are orphaned and
  remain visible for deliberate cleanup, not deleted underneath us.
- The two failing sync rows in the Port UI resolve by the mappings that produce them ceasing to
  exist — not by being fixed.
- Deleting the Ocean default blueprints is a separate, human-gated step. It is not done by
  `terraform apply`, because nothing in this repository declares those blueprints.
- `installation_app_type` must be declared on every `port_integration` resource. The provider
  sends every attribute on update and `ValueStringPointer()` returns `nil` for an undeclared
  one, so omitting it blanks the live value. Observed as
  `installation_app_type = "github-ocean" -> null` in the 20 Aug 2026 plan.
- Merged-PR history returns in Phase 4, once `G-9` has a written answer from Port support and a
  `deployment`-shaped blueprint is a decided part of the model rather than integration output.

## Risks

- The live mapping may encode a decision somebody made deliberately and did not write down.
  Mitigated, not eliminated: the full live config is preserved in the plan artifact and quoted
  in this record, so discarding it is recoverable from git history.
- Anyone re-running the Ocean installer with default resources enabled reintroduces all ten
  blocks. The next `terraform plan` shows it as an update, which is the detection mechanism —
  it depends on the plan diff actually being read.
- `installation_app_type = "gcp"` is still unconfirmed, and for GCP it goes out on a **create**
  rather than an update. See the note in `integration-gcp.tf`.

## Review trigger

`G-9` being answered, a decision to add a `deployment` blueprint to the shared model, or any
future plan showing the integration mapping as an update this repository did not author.

## Related work

- `FR-005`, `FR-013`, `FR-015` in `docs/work/PHASE2/specification.md`
- `docs/work/PHASE2/implementation-plan-fr-013.md`
- Risk areas 1, 2 and 6 in `docs/agents/project-policy.md`
- [ADR-002](ADR-002-pull-request-relates-to-service.md) — why `pull_request` targets `service`

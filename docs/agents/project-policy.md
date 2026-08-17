# Project Policy

Read by `code-review` (repository standards axis), `ponytail` (protected structures), and `grill-with-docs` (risk areas). Those skills carry no domain checklist of their own on purpose — what is written here is what they enforce.

## Risk areas

Each is a way this repository can cause real damage. A review that does not consider them has not reviewed this repository.

1. **Create-and-override data loss.** The Port Terraform provider resets any property a resource does not declare to empty on apply. A `port_entity` resource for a record type an integration owns will blank the fields that integration wrote — silently, with a clean plan. **This is the highest-severity defect class here and it does not look like a bug in a diff.**
2. **A second writer on one record type.** The same failure, arriving through good intentions. The writer table in `../mayo-port-build-spec.md` §1.3 assigns exactly one writer per record type. A diff that adds a second writer is blocking, regardless of how useful the added field is.
3. **Crossing the metadata-only boundary.** Any change that could carry PHI, secrets, or AI prompt or completion content into Port. Concretely: setting `includedFiles` in an integration mapping, ingesting ticket or page content, mapping a free-text field whose source is human prose, or adding a property that stores a payload rather than a reference. An error summary may carry a message and never a payload.
4. **Aggregating across `actor_type`.** A scorecard, aggregation property, dashboard widget, or alert that sums `developer_seat`, `agent`, and `application` spend into one figure. The number is meaningless and looks authoritative.
5. **Secrets reaching Terraform state.** Any credential expressed as a Terraform variable, default, output, or `.tfvars` entry. State is a file other people can read.
6. **Shared-module blast radius.** A change to `modules/` changes every project stack. The plan output across all of them is the required review artifact, not an optional courtesy.
7. **Destroy or replace on a shared blueprint.** A replaced blueprint takes its entities with it. `plan.yml` fails the check when the `organization` plan contains a delete; that guard is a protected structure.
8. **Presenting incomplete data as complete.** A cost view without its freshness, a quality score without its coverage, a chargeback figure without the shared-cost disclosure. Null rendered as zero. The dangerous failure in this project is not a missing number — it is a number that looks complete and is not.
9. **Wrong tenant or region.** `port_base_url` decides which Port tenant an apply writes to, and the US-versus-EU answer is also the data-residency answer.
10. **Implying enforcement.** Language, on screen or in a blueprint description, suggesting Port grants access or blocks a capability. Port shows and reflects. A registry teams believe grants access is worse than no registry.

## Evidence levels

**There is no application code in this repository yet and therefore no unit-test harness.** `tdd`, `writing-plans`, and `implement` all require an observed failing check through a public seam before the change that makes it pass. That requirement holds here; what changes is what counts as a seam and as a failure.

**The public seam for a Terraform change is the Port API's representation of the blueprint, entity, page, action, or permission — observed through `terraform plan` and through a read of the Port API. It is never the `.tf` source text.** An assertion about file contents is an implementation-detail assertion and does not satisfy the RED requirement.

The ladder, lowest rung to highest. Every rung below the highest one available must pass.

| Rung | What it proves | Command | Available today |
|---|---|---|---|
| Formatting | Nothing about behaviour; keeps diffs reviewable | `terraform fmt -check -recursive` | Yes, in `plan.yml` |
| Validity | The configuration parses and its types resolve | `terraform init -input=false` then `terraform validate` | Yes, in `plan.yml` |
| **Plan-diff assertion — this is RED and GREEN** | That the intended change, and only the intended change, reaches Port | `terraform plan -out=tfplan` then `terraform show -json tfplan`, asserted with `jq` | Yes |
| Policy | That a rule holds across all configuration, not just the diff | `conftest` / OPA against `terraform show -json` | **No — not installed.** See below |
| Lint | Provider-specific mistakes static validation misses | `tflint` | **No — not installed** |
| Runtime read-back | That Port accepted the change and stores what was intended | `terraform apply` in a **non-production organization**, then read the entity through the Port API | **No — the non-production organization does not exist yet** |
| Human | That a boundary judgement was made by someone entitled to make it | Named approval, recorded | Yes |

**What RED looks like at the plan rung.** Before the change: the plan shows the property, entity, or resource absent, or shows a `destroy`/`replace` that must not happen, or the Port API read returns 404. Capture that output. After the change: the plan shows exactly the intended `create` or `update` and no delete. A plan-diff assertion is legitimate contract evidence because the plan is derived from the provider's own view of the remote object, not from the source text.

**The honest limit, which must be stated and never papered over.** Until a non-production Port organization exists, no change can be proven by applying it anywhere except production. The highest available rung is therefore the plan-diff assertion, and a completion claim must say so rather than implying runtime evidence was captured. Two rungs are unavailable because the tooling is not installed and one because the tenant does not exist; the first two are ours to fix, the third is a Phase 0 gate. Do not claim a rung you did not run, and do not treat an unavailable rung as passed.

**When `tdd`'s stop condition fires.** "Required dependencies unavailable" applies when a change cannot be observed at the plan rung either — for example a change whose only effect is inside Port's UI rendering. Stop and say so; do not substitute a file-content assertion.

**For the Python pipeline** (`modules/ai-usage-ingestion/`, not yet written) the ordinary ladder applies with no special case: unit tests against recorded fixtures, and the whole suite must pass **without any provider credential present**. A test that needs a live key is not a test.

## External authority

Decisions this repository cannot make from its own evidence. Each needs a named person, not an inference.

- **Any `terraform apply` against the production Port organization.** Gated by the `port-production` GitHub environment with required reviewers.
- **Creating or changing Port API credentials**, and creating the GCP state bucket.
- **Anything touching the metadata-only boundary.** Mayo privacy owns this, and the no-BAA position rests on it.
- **Access, entitlement, and approval behaviour.** SailPoint's owners. Nothing SailPoint-backed is built before access exists.
- **Which git provider and which tracker the pilot uses** — unresolved in the estate, not decidable from this repository.
- **Tenant region, non-production organization, and licence count.** Port support and the commercial owner.
- **Per-person cost visibility.** Blocked until HR and the works-council position is signed off; workforce monitoring is not a technical decision.
- **Rate-card figures.** Vendor-published prices, entered with an effective-from date. Never estimated.

## Protected structures

Named so `ponytail` preserves them. Each looks removable and is not.

1. **The destroy-guard step in `.github/workflows/plan.yml`.** It fails the `organization` plan when it contains a delete. It is the only automated defence against a replaced blueprint taking its entities with it.
2. **Duplicated `providers.tf` and `backend.tf` in each stack.** Nine redundant lines, deliberately. Separate state per stack requires separate init, and Terraform does not inherit root configuration into subdirectories. A wrapper script or symlink farm would hide the stack boundary the entire ownership model rests on. See `docs/adr/ADR-001-per-stack-provider-and-state.md`.
3. **Separate state per stack.** One state file across `organization/` and every project would let one project's apply damage another's entities.
4. **Bucket versioning on the state bucket.** The recovery path from a bad apply against the shared model.
5. **The absence of stubs.** The blueprints and modules listed as deliberately missing in `README.md` are absent rather than empty because a stub applies cleanly and therefore reads as done. Adding an empty module to "complete the layout" is a regression.
6. **`includedFiles` unset, and every other unmapped field in an integration mapping.** Absence is the control.
7. **The `surface` enum having no `web` or `chat` value.** It encodes the no-web-access policy. It provides visibility, not enforcement, and the limitation is stated rather than hidden.
8. **Credentials passed only through the environment.** Not a style choice about variable hygiene.
9. **Per-source freshness records.** Removing them makes a stale dashboard indistinguishable from a current one.

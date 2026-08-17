# Domain Context Policy

## Required reading

The authoritative documents live **one directory up, outside this repository**. Read in this order; earlier wins on conflict.

1. `../mayo-port-prd.md` — the build specification. Numbered requirements with checkable "Done when" lines. **Wins over every other document, including this repository's own README.**
2. `../mayo-port-build-spec.md` — implementation companion. Repo layout, module interfaces, the writer table (§1.3), integration mapping rules, the action contract, the pipeline's internals, interface configuration. §0 separates verified vendor facts from asserted ones — check it before trusting a resource name.
3. `../prd-open-questions.md` — `PQ-*`: what is open, who owns it, what it blocks. §3 lists what is already closed, so closed points are not reopened by accident.
4. `../mayo-port-implementation-plan.md` and `../understanding.md` — the same facts as schedule and as plain language. The "why" behind the requirements.
5. `../improved/` — historical record of earlier grilling rounds. Evidence trail, not live specification.

Inside this repository: `CONTEXT.md` for durable domain truth, `docs/agents/project-policy.md` for risk and evidence rules, `docs/agents/repository-map.md` for navigation, `README.md` for operating instructions.

**Two cautions before citing anything.** The code lags the specification — `modules/core-blueprints/main.tf` still carries TODOs for blueprints the PRD already specifies, so check the code before claiming a blueprint exists. And `../understanding.md` and `../mayo-port-implementation-plan.md` restate the same facts for different audiences: a change to the model, a phase, or an open point belongs in both.

## Ownership boundaries

`CONTEXT.md` owns durable purpose, actors, terms, workflows, invariants, boundaries, and unresolved domain questions. Work-item files own task-specific facts and decisions.

The specification documents listed above are **outside this repository and outside this workflow's write scope**. They are read as authority and amended only by an explicitly authorized change of their own.

## Architecture Decision Record rule

Create a record only when the three-part gate in `docs/adr/README.md` passes.

A note on what does *not* need one: a decision already stated as a numbered requirement in the PRD or build spec has its rationale recorded there. Copying it into an ADR creates a second copy that will drift. An ADR here is for a decision **this repository** made that its specification does not cover — `ADR-001` is the example.

## Durable updates

Update durable domain context only when approved work changes durable truth; do not copy ticket narratives or session notes into it.

Specifically: when a `PQ-*` is answered, update the entry in `../prd-open-questions.md` rather than deleting it, and check whether `CONTEXT.md`'s unresolved-questions section names the same gap.

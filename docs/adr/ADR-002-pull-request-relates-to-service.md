# ADR-002: `pull_request` relates to `service`, not `repository`

- **Status:** Accepted
- **Date:** 2026-08-19
- **Owners:** manjula

## Context

`specification.md`'s `FR-015` states the new `pull_request` blueprint should be "related to
`repository`". That is not buildable as written, against the following facts in this
repository:

- `modules/core-blueprints/main.tf:187` defines the `repository` blueprint.
- `organization/main.tf:34` exports its identifier.
- `projects/mayo-pilot/github-integration.tf:70` maps GitHub's `repository` kind onto the
  **`service`** blueprint, deliberately — the comment at lines 61–69 explains why.
- Nothing anywhere creates a `repository` entity.

So `repository` is schema with zero entities, and `DM-5`'s own "Done when" — *"the pilot's
repositories appear as entities and each is reachable from its service"* — is not currently met.
A `pull_request` related to `repository` would render every pull request unattached.

## Decision

`pull_request.service` is a required single relation to `service`.

## Alternatives considered

- **Relate to `repository`, and add a second mapping to create `repository` entities.**
  Rejected: this doubles entities produced from one GitHub kind, against an unresolved `G-9`
  (Port's entity-count limits), and breaks `FR-007`'s stated entity counter.
- **Split closing the `DM-5` gap into its own work item first, then build `pull_request` against
  a real `repository` relation.** Rejected: this delays the Phase 2 exit test a full
  plan-and-review cycle.

## Consequences

- `FR-015`'s written success criterion said `repository`; it is amended to `service` in Task 8,
  with the reason recorded there rather than silently changed.
- The `DM-5` gap stays open. It is not closed by this decision — it is now recorded as an open
  item instead of silently carried.
- If `PQ-14` (whether one repository equals one service, i.e. a monorepo) resolves in favor of
  monorepos, this relation becomes wrong and needs migrating to `repository` once that blueprint
  actually gets entities.

## Risks

The `PQ-14` migration risk above, restated with its cost: `pull_request.service` is a required
relation, and the provider is create-and-override — migrating a required relation on live
entities means destroying and recreating them, not editing them in place.

## Review trigger

`PQ-14` being answered, or `DM-5`'s gap closing.

## Related work

- `FR-015` in `docs/work/PHASE2/specification.md`
- `docs/work/PHASE2/implementation-plan-fr-015.md`

## Supersession

None yet.

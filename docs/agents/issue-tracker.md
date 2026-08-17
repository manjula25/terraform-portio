# Issue Tracker

## Tracker

**Local Markdown — the approved PRD is the tracker.**

Chosen because it is the only honest answer available today: this repository has no remote, and which tracker Mayo's pilot actually uses is unresolved (both Jira keys and Azure Boards IDs appear in the estate). A GitHub or Jira tracker policy written now would presuppose that answer.

**Revisit when the git-provider question closes.** Switching means replacing this file with the `issue-tracker-github.md` or `issue-tracker-jira.md` variant from the `setup-agentic-workflow` templates and mapping the identifiers below to real tickets. Nothing else in the workflow changes, because every skill reads the tracker through this file.

## Work-item identifier

A requirement ID from the authoritative specification, used verbatim:

| Prefix | Source | Example |
|---|---|---|
| `DM-*`, `G-*`, `F-*`, `P-*`, `M-*`, `S-*`, `V-*`, `N-*` | `../mayo-port-prd.md` | `DM-8` |
| `BS-*` | `../mayo-port-build-spec.md` | `BS-11` |
| `VB-*` | `../mayo-port-build-spec.md` §0 verification tasks | `VB-1` |
| `PQ-*` | `../prd-open-questions.md` — **not work items.** An open question is answered by a named owner, not implemented | `PQ-8` |

So `docs/work/DM-8/context.md` is the captured context for the `ai_usage` → `_team` relation.

Compound work is allowed where the PRD groups it, using the lowest covering ID and naming every requirement inside — not an invented umbrella ID.

## Read procedure

1. Read the requirement from `../mayo-port-prd.md`, including its "Done when" line and any "Open" line.
2. Read the matching build-spec section when one exists, via the traceability table in the PRD's §21.
3. Read the current state of the affected files, and the writer table in `../mayo-port-build-spec.md` §1.3 for every record type the change touches.
4. Record the source path and requirement ID in the work-item context. Quote the "Done when" line as supplied acceptance criteria; label anything else as inference.
5. If the requirement carries an "Open" line pointing at a `PQ-*`, record it as a blocking unknown. Do not resolve it inside the work item.

## Write procedure

Read-only. The PRD, build spec, and open-questions file live **outside this repository** and are the authority this repository is built against; a work item never edits them. An amendment is a separate, explicitly authorized change to those documents, with the authority order in `domain.md` respected.

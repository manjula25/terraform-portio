# ADR-004: Jira issues are ingested, overriding DM-6

- **Status:** Accepted
- **Date:** 2026-08-21
- **Owners:** barani (requested and reaffirmed), manjula

## Context

`CONTEXT.md`'s external boundaries state:

> Jira and Confluence, **linked only and never ingested**

`DM-6` implements that: `project` carries `jira_project_key`,
`jira_project_url` and `confluence_space_url` — a key and two URLs a human clicks through. No
issue content crosses into Port. Those three properties were set on `project/mayo-pilot` on
20 Aug 2026 and remain set.

The user then asked for Jira to be integrated "same as GitHub", was told twice that this crosses
`invariant 1` (metadata only) and is a Mayo-privacy decision under `project-policy.md`'s external
authority list, and reaffirmed the request with credentials supplied. This record exists because
that override should be a visible decision rather than something a future reader finds in a diff.

## Decision

**Jira issues and projects are ingested into the existing `jiraIssue` and `jiraProject`
blueprints, and the mapping is owned by `projects/mayo-pilot/integration-jira.tf`.**

The mapping is deliberately narrower than Ocean's default:

| Ingested | Not ingested |
|---|---|
| `.key`, `.fields.summary` (title) | `.fields.description` |
| `status`, `issueType`, `priority`, `labels`, `components` | comments |
| `created`, `updated`, `resolutionDate` | attachments |
| `creator` (email or display name) | worklogs, changelog |
| relations to `project` and `parentIssue` | custom fields |

A summary is one line of human text and is already the outer edge of what invariant 1 tolerates.
A **description** is where pasted logs, stack traces and — in a clinical estate — patient detail
actually turn up. That distinction is the whole substance of this decision, and it is why the
override is not simply "adopt Ocean's default Jira mapping".

The JQL selector is `statusCategory != Done`, bounding the working set to live issues rather than
every ticket ever filed. That is the same unbounded-history concern `G-9` raises for merged pull
requests.

## Alternatives considered

- **Keep links only, as DM-6 specifies.** Rejected by the requester after the boundary was
  raised twice. It remains the correct posture for Mayo's tenant, and the link properties are
  still populated, so reverting this ADR does not require re-doing that work.
- **Adopt Ocean's default Jira mapping wholesale.** Rejected. Its `jiraIssue` mapping carries
  `.fields.description` and Ocean's own blueprint set. That is a materially larger privacy
  surface for no gain here, and it would create blueprints on top of the ones already present.
- **Ingest into a custom, vendor-neutral blueprint** (e.g. a `work_item` in `modules/`).
  Rejected for now: it is the right long-term shape under `T-1`, but it is a shared-model change
  affecting every project stack, and the pilot's `jiraIssue`/`jiraProject` blueprints already
  exist in the tenant. Recorded as the migration path if Jira ingestion survives the pilot.

## Consequences

- **`invariant 1` is crossed.** This is the significant one. On the sandbox site
  (`bitcot-team-vlo3lkk3.atlassian.net`, project `KAN`) the ingested text is Jira's own sample
  content, so the practical risk today is nil. Against Mayo's real Jira it is not, and this
  mapping must not reach that tenant without a named privacy approval.
- **`FR-005` stays failing.** `jiraIssue`, `jiraProject` and `jiraUser` are integration-created
  blueprints, not declared in `modules/`. They were already present — restored on 20 Aug 2026 —
  so this adds no new violation, but it does entrench one.
- **`T-1` is crossed at the mapping layer**, as it already is for the reverted GitHub mapping.
  Both target vendor-named blueprints, so switching tracker means new blueprints rather than a
  new mapping onto the same ones.
- **`PQ-6` is pre-empted, not answered.** Which tracker the pilot actually uses is still open —
  the estate shows both Jira keys and Azure Boards IDs. This commits effort to Jira before that
  resolves.
- **The catalog is a snapshot, not a live view.** The collector ran as a one-shot Docker
  container. Until it runs on a schedule (Helm) or with live events (the Terraform deployment
  method), the Jira data in Port ages silently — which is `invariant 7`, null and zero being
  different claims, applied to freshness.

## Risks

- **Self-hosted, so the failure mode is silence.** Port does not talk to Atlassian; a collector
  we run pushes in. If it stops running, nothing in Port says so — the entities simply stop
  changing. The GitHub integration at least reports "Synced with issues" in the UI.
- **The Atlassian token used for the first run was pasted into a chat transcript** and must be
  treated as compromised and rotated. The token never enters Terraform state (`invariant 8`) —
  it lives only in the collector's environment — but that does not undo the exposure.
- **Scope creep in the mapping is the thing to watch.** Adding `.fields.description` is a
  one-line change, and it is exactly the line this decision draws. Any diff that adds a free-text
  Jira field should be treated as reopening this ADR, not as a tweak.

## Review trigger

`PQ-6` being answered; a named Mayo privacy decision on Jira ingestion; any change that adds a
free-text field to the `jiraIssue` mapping; or this mapping being proposed for a tenant other
than the pilot sandbox.

## Related work

- `DM-6` — Jira and Confluence as links, in `modules/core-blueprints/main.tf`
- `invariant 1` and `invariant 8` in `CONTEXT.md`
- External authority list in `docs/agents/project-policy.md`
- [ADR-003](ADR-003-code-wins-over-live-ui-mapping.md) — reverted the same day; both records
  describe a human overriding a written boundary, which is worth reading together

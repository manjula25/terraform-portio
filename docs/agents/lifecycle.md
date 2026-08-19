# Lifecycle

**Read this before invoking any lifecycle skill.** It answers three questions and nothing else:
which skill copy is real, which stage a work item is at, and what runs next. Everything about
*how* a stage behaves lives in the skill itself; everything about *this repository's* branch
names, commands and shortened flow lives in `workflow.md`.

Last reconciled: **19 Aug 2026.**

## 1. Which skill copy is real

**One copy. The globally installed skills at `~/.claude/skills/`.** Invoke by name — `/to-spec`,
`/implement` — and do not look for a repo-local twin.

Exactly one override exists, in the planning folder one level up:

| Override | Why it exists |
|---|---|
| `../.claude/skills/grilling/` | The ADLC-shaped variant: structured inputs and outputs, `disable-model-invocation: true`, and a `Next recommended skill` line to `grill-with-docs`. The global `grilling` is a freeform "interview me relentlessly" prompt with model invocation on, so it can fire unasked and leaves no artifact the next stage can read. |

**History, so nobody restores the problem.** Until 19 Aug 2026 a tree of 21 skills sat at
`../.claude/skills/engineering/`, and the planning `CLAUDE.md` instructed agents to prefer it.
Two things were wrong at once. Twenty of the twenty-one were byte-identical to their global
twins, so the rule created seven phantom decisions to protect one real difference. And the
`engineering/` layer put every `SKILL.md` one level below where Claude Code discovers project
skills — `.claude/skills/<name>/SKILL.md` — so **none of them were ever registered**, and every
`/to-spec` or `/implement` silently loaded the global copy while the instructions claimed
otherwise. The identical copies were deleted and `grilling` promoted to the discoverable path.

**Do not create a category subdirectory under `.claude/skills/`.** A skill placed there is
invisible, which is worse than one that is absent, because the directory listing reads as
configured and the instruction to prefer it reads as followed.

## 2. Which stage a work item is at

**Decided by the files in its folder. Never from memory, and never by asking.**

```bash
ls docs/work/{WORK_ITEM_ID}/
grep -A2 '^## Status' docs/work/{WORK_ITEM_ID}/*.md
```

| Newest artifact present | Stage reached | Next skill |
|---|---|---|
| nothing | not entered | `work-item-context` |
| `context.md` | entered | `to-slices` (see §3 — `grill-with-docs` and `to-prd` are skipped) |
| `slices.md` | decomposed | `to-spec` |
| `specification.md` | specified | `writing-plans` |
| `plan.md` | planned | `ponytail`, then `implement` |
| code + evidence | implemented | `verification-before-completion` |
| verification record | verified | `code-review` |
| review | reviewed | `finishing-a-development-branch`, then `handoff` |

**Two rules that resolve most of the confusion this table used to cause:**

1. **`Draft` is not `Approved`, and the next stage requires `Approved`.** Every specify-stage
   skill names an *approved* predecessor as a required input. Building the next artifact from a
   draft is allowed and often the right call — but the new artifact must record that its
   predecessor was unapproved, in its own `## Status`, rather than implying an approval that did
   not happen. An artifact that quietly asserts a clean lineage is the failure this rule exists
   to prevent.
2. **Approval is a human act by someone entitled to perform it.** No agent moves a `## Status`
   line from `Draft` to `Approved`. The external-authority list in `project-policy.md` says who
   owns which kind of acceptance.

## 3. The chain, and where this repository leaves it

```
work-item-context → grill-with-docs → to-prd → to-slices → to-spec
                  → writing-plans → ponytail → implement (loads tdd, using-git-worktrees)
                  → verification-before-completion → code-review
                  → finishing-a-development-branch → handoff
```

**`grill-with-docs` and `to-prd` are skipped by default, and that is the normal case here, not
an exception.** `../mayo-port-prd.md` is an approved specification with numbered requirements
and checkable "Done when" lines. Re-deriving requirements would duplicate them and create an
authority conflict. So:

- the entry point is **one phase or one requirement at a time**, never the programme;
- `context.md` quotes the PRD's "Done when" line as *supplied* acceptance criteria rather than
  inferring criteria, and records the skip;
- `to-slices` therefore starts from `context.md`, and its "approved PRD" input is satisfied by
  `../mayo-port-prd.md` §N, which lives outside `docs/work/`.

**Never code straight from the PRD or a design document.** Go through the plan that `ponytail`
has simplified. The shortened flow removes the front of the chain, not the middle.

`## Next recommended skill` advances a stage. `## Handoff` delegates inside one. Helpers with no
fixed successor, invoked when needed rather than in sequence: `research`, `codebase-design`,
`domain-modeling`, `grilling`, `tdd`, `using-git-worktrees`, `diagnosing-bugs`,
`improve-codebase-architecture`, `handoff`.

The chain is convention, not enforced by the harness. Any skill can be invoked out of order;
the cost is a stop condition several stages later, when a skill finds its required input missing.

## 4. Three vocabularies that use the word "phase"

They are not the same thing and mixing them has already caused rework.

| Term | Where it comes from | What it means |
|---|---|---|
| **Phase 0–4** | `../mayo-port-prd.md` §§6–10 | Build stages of the programme. The authoritative sequence. |
| **`{WORK_ITEM_ID}` = `PHASE1`, `PHASE2`** | `docs/work/` | One PRD phase taken through the lifecycle as a single work item. Named after the PRD phase it implements. |
| **"Phase 1 / Phase 2" delivery waves** | `../prd-triage-and-phasing.md` | A client-facing re-cut of the work into two waves, grouping the IRIS-dependent parts into wave 2. **Not build stages.** That document's §7 maps between the two, and it never wins a conflict. |

When a document says "Phase 2" without qualification in this repository, it means PRD Phase 2
and the `PHASE2` work item.

## 5. Current state

| Work item | Artifacts | Stage | Blocking the next step |
|---|---|---|---|
| `PHASE1` | `context.md`, `slices.md` | decomposed | No `specification.md`. `to-spec` is the next skill if this item is resumed. |
| `PHASE2` | `context.md`, `slices.md`, `specification.md` | specified, **approved** | Both artifacts approved by manjula on 19 Aug 2026. `writing-plans` is the next skill and must be invoked by the user — it is `disable-model-invocation: true`. Three clarifications remain open and approval did not close them, so the plannable set is `FR-001`, `FR-002`, `FR-003` (+ `FR-013` when GCP access lands); the six track-dependent requirements and `FR-015` wait on `G-12` and the sponsor. |

**The S5 finding is the one to act on.** PRD Phase 2's stated exit condition promises pull
requests; no `P-*` requirement produces one, and `P-4` forbids the integration's own
pull-request blueprint. It is recorded as `FR-015` in `PHASE2/specification.md`, whose success
criteria are deliberately left unstatable until the decision is made. That is a PRD amendment
owned by the sponsor, not a local choice.

**Both PHASE2 artifacts being `Draft` is not a defect in them.** Every Phase 2 slice waits on an
input Mayo has not supplied — the pilot team's name, their git provider, their repository list,
and a human to complete the integration handshake. Four answers open most of the graph.

## 6. Keeping this file honest

It goes stale in exactly two ways, and both are cheap to fix:

- **A stage advances.** Update §5 in the same change that produces the artifact, not later.
- **Skill resolution changes** — a skill is installed, removed, or a real override is added.
  Update §1 and re-run the identical-copy check before trusting any "repo-local" claim:

  ```bash
  for s in .claude/skills/*/; do diff -rq "$s" "$HOME/.claude/skills/$(basename $s)"; done
  ```

  A copy that is identical to its global twin should be deleted, not documented.

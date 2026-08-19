# CLAUDE.md

Guidance for Claude Code and other agents working in `port-idp`.

This repository **is** the Port.io configuration for Mayo, as Terraform. Read `CONTEXT.md` first for what that means, then `README.md` for how to run it.

The specification this repository is built against lives **one directory up and outside it**: `../mayo-port-prd.md` wins on any conflict, including with this file. The full authority order is in `docs/agents/domain.md`.

## The five rules

1. **Metadata only** — never PHI, secrets, or AI prompt and completion content.
2. **Port is not an access system of record** — SailPoint owns entitlement.
3. **Config as code, always** — the UI is for throwaway exploration.
4. **One writer per record type** — because the provider is create-and-override.
5. **One model, many projects** — never fork a blueprint for one project.

Stated with their consequences in `CONTEXT.md`. The failure modes they prevent are in `docs/agents/project-policy.md`.

## Agent workflow

<!-- setup-agentic-workflow: managed section. Reconciled on rerun; edit the files it points to rather than this block. -->

Configuration for the Agentic Development Skills in this repository:

| Document | Purpose |
|---|---|
| `CONTEXT.md` | Durable purpose, actors, glossary, invariants, boundaries, open domain questions |
| `docs/agents/workflow.md` | Base branch, branch patterns, commands, worktree policy, review topology, shortened-flow rules |
| `docs/agents/issue-tracker.md` | Tracker policy and how `{WORK_ITEM_ID}` resolves |
| `docs/agents/domain.md` | Required reading, authority order, ownership boundaries, ADR rule |
| `docs/agents/project-policy.md` | Risk areas, evidence levels, external authority, protected structures |
| `docs/agents/repository-map.md` | Navigation pointers |
| `docs/adr/` | Architecture Decision Records and their three-part gate |

Work artifacts live in `docs/work/{WORK_ITEM_ID}/`.

**Entry point.** Start with `work-item-context` for one requirement, resolving the ID through `docs/agents/issue-tracker.md`. The chain — `to-slices` → `to-spec` → `writing-plans` → `ponytail` → `implement` → `verification-before-completion` → `code-review` (`to-tickets` only where a tracker is in use) — reads the artifacts the step before it wrote, so skipping the entry point makes every later step hit its stop condition. `grill-with-docs` and `to-prd` are skipped by default here because `../mayo-port-prd.md` is already an approved specification; see the shortened-flow rules in `docs/agents/workflow.md` and record the skip.

**Evidence.** There is no test harness in this repository. `docs/agents/project-policy.md` defines the ladder that stands in for one, including what RED and GREEN mean for a Terraform change and which rungs are currently unavailable. `./scripts/verify.sh` runs the available rungs and reports each exit code. Do not claim a rung you did not run.

<!-- end setup-agentic-workflow managed section -->

## Lifecycle state — read before invoking any lifecycle skill

`docs/agents/lifecycle.md` is the single answer to "which skill copy is real, which stage is this
work item at, and what runs next". It carries the current state of every work item in
`docs/work/`, and two rules worth knowing before reading anything else:

- **The lifecycle skills are the globally installed ones.** One override exists,
  `../.claude/skills/grilling/`. A tree of 21 nested copies was deleted on 19 Aug 2026 — 20 were
  byte-identical to their global twins and none were ever discoverable, so instructions to prefer
  them could not be followed. Do not recreate a category subdirectory under `.claude/skills/`.
- **A work item's stage is read from the files in its folder, never from memory.** `Draft` does not
  satisfy the next stage's required input; producing the next artifact anyway is fine, but it must
  say so in its own `## Status`.

This section sits outside the managed block deliberately, so `setup-agentic-workflow` cannot
reconcile the pointer away. The chain inside that block was also corrected to include `to-spec`;
if a rerun reverts it, `docs/agents/lifecycle.md` §3 is authoritative.

## Self-learning

When corrected, or on catching a mistake, add the lesson as a one-line rule under `## Lessons` before continuing. Project-specific lessons belong here; lessons that apply everywhere belong in `~/.claude/CLAUDE.md`.

## Lessons

- The public seam for a Terraform change is Port's API view of the object, observed through `terraform plan` and an API read — never the `.tf` source text.
- Port rejects a blueprint `description` longer than 200 characters, and `terraform plan` does not catch it — the failure lands mid-apply, after earlier resources have already been written. Measure every description before applying, not just the one being edited.

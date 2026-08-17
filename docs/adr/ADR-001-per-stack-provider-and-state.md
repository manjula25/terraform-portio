# ADR-001: Provider and backend configuration duplicated per stack

- **Status:** Accepted
- **Date:** 2026-08-17
- **Owners:** Platform team

## Context

`../../../mayo-port-implementation-plan.md` §4 shows `providers.tf` and `variables.tf` at the repository root, implying one configuration inherited by every stack.

That cannot work. `organization/` and each `projects/<name>/` are separate stacks with separate state, which requires a separate `terraform init` each, and Terraform does not inherit root-level provider or backend configuration into subdirectories. The choice is not whether to duplicate — it is where the duplication is visible.

Separate state per stack is itself load-bearing: one state file spanning the shared model and every project would let one project's apply damage another project's entities, and the Port provider's create-and-override behaviour makes that damage silent.

## Decision

Provider and backend configuration lives inside each stack, duplicated: `organization/providers.tf`, `organization/backend.tf`, `projects/<name>/providers.tf`, `projects/<name>/backend.tf`.

Roughly nine lines are repeated per stack. That is accepted as the visible cost of a boundary that must not be hidden.

## Alternatives considered

| Alternative | Why rejected |
|---|---|
| Root-level `providers.tf`, as the plan shows | Does not function. Terraform does not inherit it into subdirectories |
| Symlink the shared files into each stack | Works mechanically, but makes each stack look like it shares configuration with the others, which is the opposite of the truth being protected |
| A wrapper script that generates the files before `init` | Adds a build step in front of Terraform, and puts the boundary in code nobody reads instead of in files reviewers see in the diff |
| One state file for everything | Removes the isolation that keeps one project's apply from damaging another's entities |

## Consequences

- Adding a project means copying a directory, including its provider and backend files. Nine lines of copying is the onboarding cost.
- A provider version bump touches every stack. Intentional: it makes the blast radius visible in the pull request rather than implicit.
- The stack boundary is legible from the file tree alone.
- **`../../../mayo-port-implementation-plan.md` §4 is wrong as written and should be corrected to match.**

## Risks

Duplicated configuration can drift — for example one stack pinned to a different provider version, or one `backend.tf` still holding the placeholder bucket name. Mitigation: `terraform fmt -check -recursive` and the per-stack plan matrix in `plan.yml` run against every stack, so a stack whose configuration is broken or unpinned fails visibly rather than quietly.

## Review trigger

Revisit if Terraform gains real inheritance of provider and backend configuration into subdirectories, or if stack count grows past the point where copying is a meaningful source of drift.

## Related work

`README.md` "Deviation from plan section 4"; `docs/agents/project-policy.md` protected structures 2 and 3.

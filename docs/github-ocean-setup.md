# Connecting GitHub to Port, and putting the mapping in git

## Use GitHub (Ocean). Not "GitHub".

Port has two GitHub integrations in its catalogue right now, and picking
the wrong one wastes the work:

| Integration | Status |
|---|---|
| **GitHub (Ocean)** | Current. Use this. |
| GitHub (legacy app) | Sunset. **Fully deprecated 2026-09-15.** |

The deprecation date is under a month from 2026-08-17. Anything built on
the legacy integration in Phase 2 would need rebuilding inside the same
sprint, so there is no version of "start with the old one" that is
cheaper.

Ocean also brings the thing this engagement needs for the ingestion
counters the plan calls for: built-in sync metrics and structured logs.

## Install it — in the UI, once

Terraform cannot do this step. Installing an integration is an OAuth /
GitHub App handshake, so it happens in the Port UI. Terraform adopts the
result afterwards.

Three auth options; pick by what Mayo's GitHub admins will allow:

1. **GitHub App, created by Port** *(recommended)* — best rate limits,
   discovers every org the app is installed into, and an
   enterprise-owned app can be shared across all org accounts. In a
   regulated shop this is also the one with a reviewable permission
   list.
2. **Hosted by Port** — fully managed, least infrastructure.
3. **Personal access token** — fine-grained or classic. A classic PAT
   does multi-org via the `organizations` array. Avoid it: it is a
   named person's credential, so it dies when they leave and it
   attributes every sync to them in GitHub's audit log.

Nothing here changes the metadata-only boundary — Ocean reads repo
names, PRs, workflows and alert counts, never file contents unless
`includedFiles` is set. **Do not set `includedFiles`.** It attaches file
content to entities, and file content in a Mayo repo is exactly what the
catalog must not hold.

### During install: turn OFF "Create default resources"

This matters and it is easy to miss.

Left on, Ocean creates its own blueprints — `githubRepository`,
`githubPullRequest`, and ~16 more. You then have two service-shaped
blueprints in one catalog, which splits the model the whole engagement
is sold on. It also collides with the shared model on a later apply.

Turned off, you map GitHub's `repository` kind straight onto the shared
`service` blueprint, which is what `github-integration.tf` does.

Migrating from the legacy integration? Same toggle, same reason.

### Note the installation ID

The install screen shows an installation ID. Copy it. It goes into
`github_installation_id` in `terraform.tfvars`, and it is the address
`terraform import` needs.

## Adopt the mapping into Terraform

```bash
cd projects/mayo-pilot
cp terraform.tfvars.example terraform.tfvars   # fill it in
export PORT_CLIENT_ID=...        # from your password manager
export PORT_CLIENT_SECRET=...
terraform init
terraform import port_integration.github <installation-id>
terraform plan                    # expect: mapping changes, nothing destroyed
```

The `import` is not optional. Apply without it and Terraform either
fails or creates a second, empty integration alongside the real one.

Read the first `plan` carefully. It is the diff between what the UI's
default mapping does and what `github-integration.tf` says. From the
moment it applies, **the UI mapping editor is off limits** — the Port
provider is create-and-override, so a UI edit is silently reverted on
the next apply, and an apply silently discards a UI edit. One owner per
entity; this file is the owner.

## Watch the counters on the first sync

The plan calls this out and it is the highest-value ten minutes of
Phase 2. Three numbers, in the integration's page in Port:

- **transformed** — entities that landed. Should roughly equal the repo
  count your `repoSearch` matches.
- **filtered out** — excluded by the selector `query`. A large number
  here usually means the query is wrong, not that the repos are.
- **failed** — a jq expression or a required property that did not
  resolve. Any non-zero value is a mapping bug. Fix it now: mapping
  errors caught here never reach developers, and mapping errors caught
  later arrive as "the portal is wrong about my service".

The most likely first failure is `lifecycle` or the `project` relation —
both are required on `service`, so a repo that cannot resolve them is
dropped rather than partially created.

## Widening scope later

`github_repo_search` starts at one pilot team's repos on purpose. Widen
it in a PR, one step at a time, and re-read the counters each time.
Going straight to the full org creates hundreds of `service` entities
with no owner, and unowned entities are what makes a catalog get
ignored.

## Open points this touches

- **O-6** — the plan assumes one repo equals one service. If the pilot
  is monorepo-heavy, the `repository` kind mapping needs a
  `folder`-kind mapping alongside it, keyed on directory rather than
  repo.
- **O-5** — `service.kind` (web / mobile / api) does not exist yet, so
  ingestion cannot set it. Repos arrive kind-less and scorecards cannot
  be kind-aware until it lands.

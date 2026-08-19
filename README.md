# port-idp

Port.io for Mayo, managed as Terraform in git. This repo *is* the portal
configuration. If it is not here, it does not exist.

The design that produced this repo lives one directory up:
`mayo-port-implementation-plan.md` (authoritative) and
`understanding.md` (the same facts in plain language).

## Layout

```
modules/
  core-blueprints/     project, environment, service, ai_usage — the shared model
  scorecards/          Phase 4, not yet written
  actions/             Phase 2+, not yet written
  ai-usage-ingestion/  Phase 3, not yet written
organization/          the shared model, applied once by the platform team
projects/
  mayo-pilot/          pilot entities, GitHub mapping, permissions
docs/
  github-ocean-setup.md
.github/workflows/
  plan.yml             every PR
  apply.yml            merge to main
```

`organization/` and each `projects/<name>/` are **separate stacks with
separate state**. Adding a project means copying a project directory —
never editing `modules/`.

### Deviation from plan section 4

The plan shows `providers.tf` and `variables.tf` at the repo root. That
cannot work: separate state means a separate `terraform init` per stack,
and Terraform does not inherit root-level configuration into
subdirectories. Provider and backend config therefore lives inside each
stack, duplicated. It is nine lines and it is honest; a symlink farm or a
wrapper script would hide the stack boundary that the ownership model
depends on. **Plan section 4 should be corrected to match.**

## First-time setup

### 1. Credentials

Port API credentials come from **Settings → Credentials** in Port. They
are org-level and powerful.

```bash
export PORT_CLIENT_ID=...
export PORT_CLIENT_SECRET=...
```

Never in a `.tfvars` file, never in the repo, never as a Terraform
variable — a variable ends up in state, and state is a file other people
can read. In CI they are the `PORT_CLIENT_ID` / `PORT_CLIENT_SECRET`
repository secrets.

The same rule, harder, for the Anthropic Admin/Analytics and OpenAI
org keys that Phase 3 needs: GCP Secret Manager, fetched at runtime by
the ingestion job, never touched by Terraform.

### 2. Confirm the tenant region

`port_base_url` decides which tenant Terraform writes to.

| Region | App | API |
|---|---|---|
| EU | `app.port.io` | `https://api.port.io` |
| US | `app.us.port.io` | `https://api.us.port.io` |

**Confirmed EU, 2026-08-18 (G-3).** The credentials in use return `200`
from `https://api.port.io` and `401` from `https://api.us.port.io`, so
the default here is EU. This was measured, not assumed — the plan
documents had it down as US, which is exactly why G-3 is a gate.

Re-check it if the credentials ever change: the tenant and the
credentials move together, in the same pull request, or Terraform points
at one tenant with another's keys. This also decides the data-residency
story. (The legacy `*.getport.io` hostnames still resolve; the
`*.port.io` form is the documented one.)

### 3. State bucket

```bash
gsutil mb -p <GCP_PROJECT> -l us-central1 gs://mayo-port-idp-tfstate
gsutil versioning set on gs://mayo-port-idp-tfstate
gsutil uniformbucketlevelaccess set on gs://mayo-port-idp-tfstate
```

Versioning is not optional. The Port provider is create-and-override, so
one bad apply against `organization/` can blank properties across every
project at once, and the previous state version is how you get back.

Then replace `REPLACE-ME-mayo-port-idp-tfstate` in both `backend.tf`
files.

### 4. Apply the shared model

```bash
cd organization
terraform init
terraform plan     # expect: 4 blueprints to create
terraform apply
```

Four blueprints should appear in Port. That is Phase 1's exit criteria.

### 5. The pilot stack

Needs the pilot to have been named (Phase 0) and GitHub (Ocean) to have
been installed. See `docs/github-ocean-setup.md` — there is a
`terraform import` step that is not optional.

```bash
cd projects/mayo-pilot
cp terraform.tfvars.example terraform.tfvars   # fill it in
terraform init
terraform import port_integration.github <installation-id>
terraform plan
```

### 6. CI

Repository **secrets**: `PORT_CLIENT_ID`, `PORT_CLIENT_SECRET`.
Repository **variables**: `GCP_WORKLOAD_IDENTITY_PROVIDER`,
`GCP_TERRAFORM_SERVICE_ACCOUNT` (keyless auth to the state bucket — no
service-account JSON key in a secret).

A GitHub environment named `port-production` with required reviewers
gates `apply`.

Branch protection to match the plan's Phase 1 deliverable: platform team
can merge changes to `modules/`, project leads cannot. A `CODEOWNERS`
entry for `modules/` and `organization/` is how that gets enforced —
**not yet written**, because it needs the real GitHub team names.

## The rules this repo enforces

1. **Metadata only.** Names, links, counts, dollars. Never PHI, never
   secrets, never AI prompt or completion content. Crossing this puts
   Port inside the PHI boundary and reopens the whole compliance
   posture. Concretely: do not set `includedFiles` in the GitHub
   mapping.
2. **Port is not an access system of record.** SailPoint owns approval
   and provisioning. Port shows the button and reflects status back.
3. **Config as code, always.** The UI is for throwaway prototyping.
4. **One owner per entity.** Create-and-override means half-UI,
   half-Terraform is worse than either extreme.
5. **One model, many projects.** Per-project differences live in
   entities and permissions, never in forked blueprints.

## What is deliberately not here

Stubs that apply cleanly read as "done", so these are absent rather than
empty:

- scorecards, self-service actions, permissions, the AI-usage ingestion
  pipeline
- `CODEOWNERS`
- entities of any kind in the `skill` and `mcp_server` registries.
  Phase 1 declares their schema and nothing else (**DM-16**); the
  permission model lands in Phase 2 (**P-9**), once teams are synced
  and there are real entities to scope against
- relations to Jira project and Confluence space on `service`. They sit
  on `project` instead (**DM-6**), because `service` is written by the
  git integration and a second writer risks blanking ingested fields

## Model gaps that are now closed

Both blocked the pilot and both are applied:

- **O-5** → `service.kind`, required, five values (`web`, `mobile`,
  `api`, `worker`, `job`) with kind-specific field groups (**DM-4**).
  Three kinds could not describe an estate with a worker, two jobs, and
  a proxy in it.
- **O-1** → `ai_usage` relates to the native `_team` blueprint
  (**DM-8**). This is what moves "spend by team" from Blocked to Safe —
  *provided* Entra groups turn out to match the real delivery squads
  (**PQ-10**). If they mirror the org chart instead, the rollups
  describe reporting lines rather than teams.

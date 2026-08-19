# Setting Up and Testing the GitHub (Ocean) Integration — Sandbox Walkthrough

This is a personal walkthrough for testing the GitHub integration against your own
`bitcot/port-io` sandbox — it is **separate from the Mayo pilot work** in
`docs/work/PHASE2/`, which is still blocked on Mayo naming a pilot team and confirming
GitHub vs. Azure DevOps (`G-11`, `G-12`). Nothing here should be treated as satisfying
any `FR-004`–`FR-009` requirement for that work item.

Repository reference: `docs/github-ocean-setup.md` in this repo covers the same ground
in more general terms; this file sequences it into concrete steps for this setup.

## Before you start

- You'll need a Port account with permission to install data sources.
- You'll need admin access to the `bitcot` GitHub org (or at least to install a GitHub
  App into it) — or you can point this at a personal repo instead, adjusting the org
  name below.
- Rotate your Port credentials first if you haven't yet — a client ID/secret was
  exposed in a prior session and should not be reused.
- Every step below that touches real state (`terraform apply`) is something to run
  yourself, deliberately, one at a time. Don't script past step 7.

---

## Step 1 — Install the GitHub (Ocean) integration in Port's UI

This is the one step Terraform cannot do — it's an OAuth / GitHub App handshake.

1. Log into Port.
2. Go to **Settings → Data sources → GitHub**.
3. Confirm you're installing **GitHub (Ocean)** — not the legacy "GitHub" integration
   (that one is deprecated 2026-09-15).
4. Choose an auth option. For a personal sandbox, "GitHub App, created by Port" is
   simplest.
5. **Before finishing the install, find the "Create default resources" toggle and turn
   it OFF.** This is the step Phase 1 got bitten by — leaving it on creates ~18 of
   Port's own blueprints (`githubRepository`, `githubPullRequest`, etc.) that collide
   with the shared model already in this repo.
6. Complete the GitHub App installation into the `bitcot` org (or wherever you want to
   test), authorizing whichever repos you want visible — e.g. just `port-io`.
7. **Copy the installation ID** shown on the install-complete screen. You'll need it in
   Step 3.

## Step 2 — Decide what to ingest

Pick values for the three variables the mapping needs:

- `github_organizations` — e.g. `["bitcot"]`
- `github_repo_search` — a narrow GitHub search query. Start with one repo, not the
  whole org:
  `"org:bitcot repo:bitcot/port-io"`
  (Widening this later is a one-line change; narrowing after an over-broad sync means
  cleaning up entities nobody owns.)

## Step 3 — Fill in your local `terraform.tfvars`

This file is gitignored — it never gets committed. In
`projects/mayo-pilot/terraform.tfvars` (or wherever you're running this from), set:

```hcl
github_installation_id = "<the installation ID from Step 1, lowercase letters/numbers/dashes only>"
github_organizations   = ["bitcot"]
github_repo_search     = "org:bitcot repo:bitcot/port-io"
```

Leave every other variable (`project_identifier`, `owning_team`, etc.) as whatever
you're already using for your sandbox test — they don't need to be real Mayo values
for this test to work, but `owning_team` does need to be a team that actually exists in
your Port organization (teams come from your IdP/SSO, not from Terraform).

## Step 4 — Export credentials and initialize

```bash
export PORT_CLIENT_ID=...        # your Port credential, freshly rotated
export PORT_CLIENT_SECRET=...
cd projects/mayo-pilot
terraform init -input=false
```

Expect: `Terraform has been successfully initialized!`

## Step 5 — Import the integration (do not skip this)

```bash
terraform import port_integration.github <installation-id-from-step-1>
```

Expect: `Import successful!`

**If you skip this and go straight to `terraform apply`,** Terraform will try to
*create* a new integration instead of adopting the one you just installed. That fails
with a cryptic-looking error (`"installationAppType" must be string`) — this is
expected behavior from the provider refusing to create what should only be imported,
not a bug to work around. If you see that error, come back to this step.

## Step 6 — Plan, and actually read it

```bash
terraform plan -input=false -out=tfplan
```

Read the output carefully. It's the diff between what the UI's default mapping did on
install and what `github-integration.tf` says should be there. Expect: changes to the
integration's `config` (mapping repos onto the shared `service` blueprint), **and no
destroy**. If you see anything destroying an existing entity, stop and figure out why
before applying.

## Step 7 — Apply (this is the one real action)

```bash
terraform apply "tfplan"
```

This writes the mapping to Port. From this moment, **the Port UI's mapping editor is
off limits for this integration** — the provider is create-and-override, so editing in
the UI will get silently reverted on the next `apply`, and editing here will silently
discard whatever's in the UI. Pick one place to edit: this file.

## Step 8 — Watch the first sync

In Port's UI, open the GitHub integration's page and find the sync counters:

- **transformed** — entities that landed. Should roughly equal your repo count (1, if
  you scoped to a single repo in Step 2).
- **filtered out** — excluded by the mapping's selector query. A large number here
  usually means the query is wrong.
- **failed** — a jq expression or required property that didn't resolve. **Any
  non-zero value here is a mapping bug worth fixing before doing anything else.** The
  most likely cause is the `lifecycle` or `project` relation not resolving.

## Step 9 — Confirm in the catalog

Go to Port's Service catalog and confirm your `bitcot/port-io` repo shows up as a
`service` entity, with `lifecycle = experimental` (never `production` — nothing should
set that automatically) and its `project` relation pointing at whatever project you
used.

## Step 10 — Widen scope later, one step at a time

Once the counters look clean for one repo, widen `github_repo_search` to more repos in
a deliberate step (e.g. drop the `repo:` filter to include the whole org, or add a
topic filter), re-plan, re-check the counters, and only then apply again. Going
straight to the whole org on day one is how a catalog ends up full of entities nobody
owns.

---

## If something goes wrong

- **Stale state lock** (`Error acquiring the state lock`): check for a hung/suspended
  `terraform` process (`ps aux | grep terraform`) and kill it before retrying —
  `force-unlock` won't help if the OS-level file lock is still held by a live process.
- **`"installationAppType" must be string"`**: you skipped Step 5. Go back and import.
- **Non-zero `failed` counter**: check that the repo you're syncing has a resolvable
  `lifecycle` and `project` relation in the mapping (`github-integration.tf`) before
  touching anything else.

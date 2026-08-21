# Setting Up and Testing the GitHub (Ocean) Integration — Sandbox Walkthrough

This is a personal walkthrough for testing the GitHub integration — it is **separate
from the Mayo pilot work** in `docs/work/PHASE2/`, which is still blocked on Mayo
naming a pilot team and confirming GitHub vs. Azure DevOps (`G-11`, `G-12`). Nothing
here should be treated as satisfying any `FR-004`–`FR-009` requirement for that work
item.

Repository reference: `docs/github-ocean-setup.md` in this repo covers the same ground
in more general terms; this file sequences it into concrete steps and records the two
real gotchas hit while actually doing it.

## Before you start

- You'll need a Port account with permission to install data sources.
- **Org-level GitHub App installs need org OWNER, not just repo admin.** The first
  attempt here was against the `bitcot` org — blocked, because the account installing
  the app was a repo admin on `bitcot/port-io` but not an org owner. GitHub only offers
  "No repositories" with a disabled "Update access" button in that case; there's no fix
  from that screen, only from the org's owner list.
- **The simplest sandbox path is a personal repo you actually admin**, e.g.
  `https://github.com/<you>/<repo>`. A personal GitHub account isn't an "org" for
  install purposes, and admin on your own repo is enough to grant the app access.
  This walkthrough now uses that path (`manjula25/terraform-portio`) as the working
  example.
- Rotate your Port credentials if you haven't yet — a client ID/secret was exposed in
  a prior session and should not be reused.
- Every step below that touches real state (`terraform apply`) is something to run
  yourself, deliberately, one at a time. Don't script past step 7.

---

## Step 1 — Install the GitHub (Ocean) integration in Port's UI

This is the one step Terraform cannot do — it's an OAuth / GitHub App handshake.

1. Log into Port.
2. Go to **Settings → Data sources**, click **New data source → Integrations → GitHub**.
3. Confirm you're installing **GitHub (Ocean)** — not the legacy "GitHub" integration
   (that one is deprecated 2026-09-15).
4. Name the data source (this name, e.g. `github-ocean`, is just a label — **it is not
   the installation ID**; see the warning in Step 3 below).
5. Choose an installation method:
   - **"GitHub App, created by Port"** installs a real GitHub App into an org or your
     personal account. Requires org-owner permission if targeting an org.
   - **"Hosted by Port"** is fully managed and was the path that actually worked here
     without needing org-owner rights.
6. **Before finishing, expand "Advanced Configuration" and look for a "Create default
   resources" toggle. Turn it OFF if present.** This is the step Phase 1 got bitten by
   — leaving it on creates ~18 of Port's own blueprints (`githubRepository`,
   `githubPullRequest`, etc.) that collide with the shared model already in this repo.
7. Complete the installation, authorizing whichever repo(s) you want visible — e.g.
   just `terraform-portio`.

## Step 2 — Find the real installation ID (not the data-source name)

**Corrected 20 Aug 2026 — this section previously told you to use the numeric ID.**

The GitHub App's installation page (`github.com/apps/<app-name>/installations/<numeric-id>`)
shows a numeric ID such as `154905752`. **That is a GitHub-side number and Port does not key
the integration on it.** Verified against the live tenant:

```
GET /v1/integration/154905752     -> 404
GET /v1/integration/github-ocean  -> 200
```

What Terraform needs is Port's own `installationId`, a lowercase-dash slug — `github-ocean`
for a default Ocean GitHub install. Ask the API rather than the UI; it is the field Terraform
actually reads:

```bash
curl -s -X POST https://api.port.io/v1/auth/access_token \
  -H "Content-Type: application/json" \
  -d '{"clientId": "YOUR_CLIENT_ID", "clientSecret": "YOUR_CLIENT_SECRET"}' \
  | jq -r .accessToken
```

```bash
curl -s https://api.port.io/v1/integration \
  -H "Authorization: Bearer YOUR_TOKEN" | jq '.integrations[] | {installationId, title}'
```

Match the `title` to the data source you just created; `installationId` is the value
that goes into `terraform.tfvars`.

## Step 3 — Decide what to ingest

Pick values for the three variables the mapping needs. **A personal GitHub account is
not an org** — GitHub's search syntax uses `user:`, not `org:`, for a personal
account:

- `github_organizations` — the account or org that owns the repo, e.g. `["manjula25"]`
- `github_repo_search` — a narrow query scoped to one repo:
  `"user:manjula25 repo:manjula25/terraform-portio"`
  (For an actual GitHub *organization* rather than a personal account, use `org:` in
  place of `user:`. Widening the query later is a one-line change; narrowing after an
  over-broad sync means cleaning up entities nobody owns.)

## Step 4 — Fill in your local `terraform.tfvars`

This file is gitignored — it never gets committed. In
`projects/mayo-pilot/terraform.tfvars` (or wherever you're running this from), set:

```hcl
github_installation_id = "github-ocean"
github_organizations   = ["manjula25"]
github_repo_search     = "repo:manjula25/terraform-portio"
```

Leave every other variable (`project_identifier`, `owning_team`, etc.) as whatever
you're already using for your sandbox test — they don't need to be real Mayo values
for this test to work, but `owning_team` does need to be a team that actually exists in
your Port organization (teams come from your IdP/SSO, not from Terraform).

## Step 5 — Export credentials and initialize

```bash
export PORT_CLIENT_ID=...        # your Port credential, freshly rotated
export PORT_CLIENT_SECRET=...
cd projects/mayo-pilot
terraform init -input=false
```

Expect: `Terraform has been successfully initialized!`

## Step 6 — Import the integration (do not skip this)

```bash
terraform import port_integration.github github-ocean
```

Expect: `Import successful!`

**If you skip this and go straight to `terraform apply`,** Terraform will try to
*create* a new integration instead of adopting the one you just installed. That fails
with a cryptic-looking error:

```
{"ok":false,"error":"invalid_request","message":"\"installationAppType\" must be string"}
```

This is **expected behavior**, not a config bug — the `port_integration` resource's
own schema says it "manages existing integration and integration mappings, not for
creating new integrations." Seeing this error means you skipped this step; it does not
mean the mapping in `github-integration.tf` needs fixing.

## Step 7 — Plan, and actually read it

```bash
terraform plan -input=false -out=tfplan
```

Read the output carefully. It's the diff between what the UI's default mapping did on
install and what `github-integration.tf` says should be there. Expect: changes to the
integration's `config` (mapping repos onto the shared `service` blueprint), **and no
destroy**. If you see anything destroying an existing entity, stop and figure out why
before applying.

## Step 8 — Apply (this is the one real action)

```bash
terraform apply "tfplan"
```

This writes the mapping to Port. From this moment, **the Port UI's mapping editor is
off limits for this integration** — the provider is create-and-override, so editing in
the UI will get silently reverted on the next `apply`, and editing here will silently
discard whatever's in the UI. Pick one place to edit: this file.

## Step 9 — Watch the first sync

In Port's UI, open the GitHub integration's page and find the sync counters:

- **transformed** — entities that landed. Should roughly equal your repo count (1, if
  you scoped to a single repo in Step 3).
- **filtered out** — excluded by the mapping's selector query. A large number here
  usually means the query is wrong.
- **failed** — a jq expression or required property that didn't resolve. **Any
  non-zero value here is a mapping bug worth fixing before doing anything else.** The
  most likely cause is the `lifecycle` or `project` relation not resolving.

## Step 10 — Confirm in the catalog

Go to Port's Service catalog and confirm your repo shows up as a `service` entity,
with `lifecycle = experimental` (never `production` — nothing should set that
automatically) and its `project` relation pointing at whatever project you used.

## Step 11 — Widen scope later, one step at a time

Once the counters look clean for one repo, widen `github_repo_search` to more repos in
a deliberate step (e.g. drop the `repo:` filter to include the whole account/org, or
add a topic filter), re-plan, re-check the counters, and only then apply again. Going
straight to the whole org on day one is how a catalog ends up full of entities nobody
owns.

---

## If something goes wrong

- **GitHub shows only "No repositories" with "Update access" disabled**: you're not an
  org owner (repo admin isn't enough for an org-level app install). Either get an
  owner to grant access, or switch to a personal repo you actually admin, or use the
  "Hosted by Port" installation method instead of "GitHub App, created by Port."
- **Stale state lock** (`Error acquiring the state lock`): check for a hung/suspended
  `terraform` process (`ps aux | grep terraform`) and kill it before retrying —
  `force-unlock` won't help if the OS-level file lock is still held by a live process.
- **`"installationAppType" must be string"`**: you skipped Step 6. Go back and import.
- **Non-zero `failed` counter**: check that the repo you're syncing has a resolvable
  `lifecycle` and `project` relation in the mapping (`github-integration.tf`) before
  touching anything else.

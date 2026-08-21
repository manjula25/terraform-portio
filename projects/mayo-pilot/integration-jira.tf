####################################################################
# Jira (Ocean) integration mapping, as code.
#
# THIS OVERRIDES DM-6, AND THAT IS A DELIBERATE HUMAN DECISION, NOT AN
# OVERSIGHT. `CONTEXT.md`'s external boundaries read "Jira and
# Confluence, linked only and never ingested", and this file ingests
# issues. The override was requested explicitly and repeated after the
# boundary was raised twice. See `docs/adr/ADR-004-jira-ingestion.md`
# for the decision, its cost, and what has to be true before this runs
# anywhere near Mayo's tenant.
#
# What that costs, stated where someone editing this file will see it:
#
#   - Invariant 1 (metadata only) is crossed. A Jira issue's summary is
#     human free text. On this sandbox that text is Jira's own sample
#     content; against Mayo's real Jira it could carry patient detail,
#     which is why the mapping below takes `.fields.summary` as a title
#     and NOTHING from `.fields.description`, comments, or attachments.
#   - `FR-005` stays failing: jiraProject and jiraIssue are
#     integration-created blueprints, not declared in `modules/`.
#   - `T-1` is crossed at the mapping layer, as it already is for the
#     reverted GitHub mapping: these blueprints name a vendor.
#
# SELF-HOSTED, NOT HOSTED BY PORT. This is the GCP pattern, not the
# GitHub one, and the difference was established by measurement:
#
#   github-ocean      installationType = SaasOAuth2   Port runs it
#   jira-mayo-pilot   installationType = OnPrem       we run it
#
# So Port never talks to Atlassian. A collector runs on our
# infrastructure, reads Jira with an Atlassian API token, and pushes
# into Port with PORT_CLIENT_ID / PORT_CLIENT_SECRET. Terraform owns the
# MAPPING only — it cannot install or run the collector, exactly as with
# `integration-gcp.tf`.
#
# The collector is a one-shot Docker run today, which means the catalog
# is a snapshot and goes stale. A real deployment needs Helm (scheduled)
# or the Terraform method (live events); neither `helm` nor `kubectl` is
# available on the machine this was first run from.
#
# TO RUN A SYNC, from the repository root:
#
#   docker run --rm --env-file .env.jira \
#     ghcr.io/port-labs/port-ocean-jira:latest
#
# `.env.jira` is gitignored (.env.* ) and chmod 600. It is a SIBLING of
# .env rather than part of it, so the Atlassian token is not exported
# into every shell that runs terraform. Its own header documents the
# variables; the two that bite are:
#
#   OCEAN__INTEGRATION__IDENTIFIER must equal var.jira_installation_id,
#     or the import adopts nothing and the apply makes a second, empty
#     integration.
#   OCEAN__CREATE_PORT_RESOURCES_ORIGIN = "Empty", or Ocean creates its
#     own Jira blueprints on top of the existing ones.
#
# The Atlassian value must be a PERSONAL API token from
# id.atlassian.com/manage-profile/security/api-tokens (prefix ATATT),
# not an org admin key from admin.atlassian.com (prefix ATCTT). The
# admin key fails Basic auth with 401 while /project/search still
# answers anonymously with total 0 — so the collector reports "0 raw
# results" and reads as a filter bug rather than an auth failure.
#
# `CREATE_PORT_RESOURCES_ORIGIN=Empty` is not optional. Without it Ocean
# creates its own Jira blueprints on top of the ones already in this
# tenant, which is the incident FR-005 exists to prevent.
#
# THE ATLASSIAN TOKEN NEVER ENTERS TERRAFORM. Invariant 8: secrets never
# reach Terraform state. It lives in the collector's environment only,
# and the token used for the first run on 20 Aug 2026 was pasted into a
# chat transcript and must be treated as compromised.
#
# `installation_id` is a value WE CHOOSE and hand to the collector, the
# same as GCP — the collector's OCEAN__INTEGRATION__IDENTIFIER and
# var.jira_installation_id must be the same string, or the import adopts
# nothing and the apply creates a second, empty integration.
####################################################################

resource "port_integration" "jira" {
  installation_id       = var.jira_installation_id
  installation_app_type = "jira"
  title                 = "Jira — Mayo pilot"

  config = jsonencode({
    createMissingRelatedEntities = false

    # false: orphan rather than destroy. A narrowed JQL filter should not
    # silently delete catalog entries. Risk area 1 in project-policy.md.
    deleteDependentEntities = false

    resources = [
      {
        kind = "project"
        selector = {
          query = "true"
        }
        port = {
          # An OBJECT, not a one-element list. Ocean's config validator
          # rejects a list with "value is not a valid dict" and the sync
          # then aborts before fetching anything — 94 validation errors
          # on the GitHub integration on 20 Aug 2026, which is the same
          # trap reached from a different file.
          entity = {
            mappings = {
              identifier = ".key"
              title      = ".name"
              blueprint  = "\"jiraProject\""
              properties = {
                url = "\"${var.jira_host}/jira/software/projects/\" + .key"
              }
            }
          }
        }
      },
      {
        # Jira users -> jiraUser. Requested 21 Aug 2026.
        #
        # FILTERED TO REAL PEOPLE. This site returns 46 users, of which
        # 45 are Atlassian marketplace app accounts — "Blocker Checker",
        # "Brand Voice Crafter", "Global Translator" and so on — and one
        # is a person. Ingesting all 46 would make the Jira Users table
        # a list of installed add-ons with a human hidden in it, which
        # tells a reader nothing. `accountType == "atlassian"` is the
        # field that separates them.
        #
        # Measured: {'atlassian': 1, 'app': 45}.
        kind = "user"
        selector = {
          query = ".accountType == \"atlassian\""
        }
        port = {
          entity = {
            mappings = {
              # accountId, not the email. It is Atlassian's stable
              # identifier and survives a display-name change; an email
              # as an identifier would also put a personal address in
              # every relation that points here.
              identifier = ".accountId"
              title      = ".displayName"
              blueprint  = "\"jiraUser\""

              properties = {
                displayName = ".displayName"
                active      = ".active"
                accountType = ".accountType"

                # emailAddress is DELIBERATELY NOT MAPPED, even though
                # the blueprint has the property and Jira returns it.
                #
                # B-1: a handle, never an email. The same rule already
                # governs pull_request.author in
                # modules/core-blueprints/main.tf — "an email here would
                # make the catalog a directory of who changed what,
                # which is a different privacy question than the one
                # G-2 answered". A Jira user table is exactly that
                # directory, and the display name identifies a person
                # for catalog purposes without publishing their address.
                #
                # Also practical: app accounts return null for it, so
                # mapping it would need the same `if . then` guard as
                # priority — but the reason it is absent is the rule,
                # not the null.
              }
            }
          }
        }
      },
      {
        kind = "issue"
        selector = {
          # JQL, not jq. Bounded deliberately: `statusCategory != Done`
          # keeps the working set to live issues rather than pulling
          # every ticket ever filed, which is the same unbounded-history
          # question G-9 raises for merged pull requests.
          query = "true"
          jql   = "statusCategory != Done"
        }
        port = {
          entity = {
            mappings = {
              identifier = ".key"

              # Summary only. NOT .fields.description, not comments, not
              # attachments. A summary is a line of human text and is
              # already the outer edge of what invariant 1 tolerates;
              # a description is where pasted logs and patient detail
              # actually turn up.
              title     = ".fields.summary"
              blueprint = "\"jiraIssue\""

              properties = {
                url        = "\"${var.jira_host}/browse/\" + .key"
                status     = ".fields.status.name"
                issueType  = ".fields.issuetype.name"
                components = "[.fields.components[].name]"
                creator    = ".fields.creator.emailAddress // .fields.creator.displayName"

                # Guarded: this project has no priority scheme, so
                # .fields.priority is null on every issue and
                # `.fields.priority.name` fails with "Cannot index null".
                # Measured 20 Aug 2026 — "Mapping error for kind issue:
                # priority, resolutionDate (5 rows affected)".
                priority       = "if .fields.priority then .fields.priority.name else empty end"
                labels         = ".fields.labels"
                created        = ".fields.created"
                updated        = ".fields.updated"
                resolutionDate = "if .fields.resolutiondate then .fields.resolutiondate else empty end"
              }

              relations = {
                project = ".fields.project.key"

                # -> jiraUser, matching the `user` kind above. NOT the
                # `assignee`/`reporter` relations, which target Port's
                # native _user blueprint and would need every Jira
                # account to exist as a Port user first.
                #
                # Guarded: every issue on this board is Unassigned, so
                # .fields.assignee is null throughout. `if . then` yields
                # nothing rather than sending null, the same form
                # priority and resolutionDate needed — `// empty` would
                # pass the null straight through.
                #
                # Safe against the parentIssue trap: both resolve to
                # jiraUser entities the `user` kind creates in the same
                # sync, not to issues the JQL filter excludes. The
                # reporter here is the one real person on the site; if a
                # reporter were ever an app account the selector filters
                # it out and this relation would dangle — worth
                # re-checking if the user filter is ever widened.
                jira_user_assignee = "if .fields.assignee then .fields.assignee.accountId else empty end"
                jira_user_reporter = "if .fields.reporter then .fields.reporter.accountId else empty end"

                # parentIssue is DELIBERATELY NOT MAPPED.
                #
                # It resolved, but to issues the JQL filter excludes. A
                # subtask whose parent is Done points at an entity that
                # was never ingested, and createMissingRelatedEntities is
                # false, so Port rejected the whole entity:
                #
                #   Failed to ingest entities for kind issue: SAM1-10:
                #   Entity with identifier "SAM1-5" does not exist in
                #   the blueprint "jiraIssue"
                #
                # Nine of fourteen issues were lost to this. The parent
                # relation is only safe once the selector stops filtering
                # by status, which reintroduces the unbounded-history
                # question G-9 raises — so the relation waits for that
                # decision rather than forcing it.
              }
            }
          }
        }
      },
    ]
  })
}

output "jira_integration_id" {
  description = "Port's internal id for the adopted Jira integration."
  value       = port_integration.jira.id
}

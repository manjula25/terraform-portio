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
#   docker run --rm --env-file <env> \
#     ghcr.io/port-labs/port-ocean-jira:latest
#
#   OCEAN__INTEGRATION__IDENTIFIER      = var.jira_installation_id
#   OCEAN__INTEGRATION__CONFIG__JIRA_HOST
#   OCEAN__INTEGRATION__CONFIG__ATLASSIAN_USER_EMAIL
#   OCEAN__INTEGRATION__CONFIG__ATLASSIAN_USER_TOKEN
#   OCEAN__CREATE_PORT_RESOURCES_ORIGIN = "Empty"
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
                url            = "\"${var.jira_host}/browse/\" + .key"
                status         = ".fields.status.name"
                issueType      = ".fields.issuetype.name"
                components     = "[.fields.components[].name]"
                creator        = ".fields.creator.emailAddress // .fields.creator.displayName"
                priority       = ".fields.priority.name"
                labels         = ".fields.labels"
                created        = ".fields.created"
                updated        = ".fields.updated"
                resolutionDate = "if .fields.resolutiondate then .fields.resolutiondate else empty end"
              }

              relations = {
                project = ".fields.project.key"

                # `if ... else empty end`, not `// empty`: null is a
                # legitimate value to jq's alternative operator, so `//`
                # passes null straight through and Port rejects it. This
                # exact form was needed for merged_at/closed_at on the
                # pull_request mapping the same day.
                parentIssue = "if .fields.parent then .fields.parent.key else empty end"
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

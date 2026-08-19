####################################################################
# GitHub (Ocean) integration mapping, as code.
#
# READ THIS BEFORE APPLYING
#
# Terraform does not install the integration. Installation is an OAuth
# / GitHub App handshake that has to happen in the Port UI (or via the
# hosted-by-Port option). What Terraform owns is the MAPPING, adopted
# from the already-installed integration with `terraform import`:
#
#   terraform import port_integration.github <installation-id>
#
# Skipping the import and applying straight away will fail or create a
# second, empty integration. Full sequence in docs/github-ocean-setup.md.
#
# The provider's own schema says it outright: "This resource manages
# existing integration and integration mappings, not for creating new
# integrations." Apply before import and Port's API rejects the create
# with a message that looks like a config bug but is not one:
#
#   {"ok":false,"error":"invalid_request","message":"\"installationAppType\" must be string"}
#
# That field is never set here on purpose — it only matters on the
# create path this file is not meant to take. Seeing this error means
# the import step was skipped, not that this mapping needs a fix. Run
# the import and re-plan.
#
# The provider is create-and-override: once this resource is imported,
# the UI mapping editor is off limits. A UI edit is silently reverted on
# the next apply, and an edit here silently discards the UI's version.
# One owner per entity — this file is the owner.
#
# Use the GitHub (Ocean) integration, not the legacy "GitHub" one. The
# legacy integration is sunset and is fully deprecated on
# 2026-09-15 — under a month from now.
####################################################################

resource "port_integration" "github" {
  installation_id = var.github_installation_id
  title           = "GitHub — Mayo pilot"

  config = jsonencode({
    # Private repos only. A HIPAA/HITRUST org has no business ingesting
    # public forks into the catalog.
    repositoryType = "private"

    # Start narrow. Widening is a one-line PR; unwinding a full-org
    # sync that created hundreds of unowned services is not.
    repoSearch    = var.github_repo_search
    organizations = var.github_organizations

    # Mapping lives here, not in the org's .github-private repo. Two
    # sources of mapping truth is the same failure mode as UI + Terraform.
    repoManagedMapping = false

    createMissingRelatedEntities = false
    deleteDependentEntities      = true

    resources = [
      {
        # Repository -> our own `service` blueprint, not Ocean's default
        # `githubRepository`. Keeping the shared model as the only
        # service-shaped blueprint is what "one model, many projects"
        # means; a parallel githubRepository blueprint would split the
        # catalog in two.
        #
        # This requires "Create default resources" to be OFF when the
        # integration is installed, or Ocean's own blueprints land first
        # and collide.
        kind = "repository"
        selector = {
          query = "true"
        }
        port = {
          entity = {
            mappings = [{
              identifier = ".name"
              title      = ".name"
              blueprint  = "\"service\""
              properties = {
                # jq expressions, evaluated against the GitHub API
                # response. Strings must be quoted inside the expression
                # to be literals.
                language = ".language // \"other\" | ascii_downcase"

                # Ingestion cannot know lifecycle. Everything arrives
                # experimental and is promoted deliberately, by a human
                # or by a later mapping rule on a repo topic. Defaulting
                # to "production" would hand every new repo a
                # production scorecard it has not earned.
                lifecycle = "\"experimental\""

                repo_url   = ".html_url"
                readme_url = ".html_url + \"#readme\""
              }
              relations = {
                # Every ingested service is pinned to this project. This
                # is why the integration is scoped per project stack
                # rather than installed once org-wide.
                project = "\"${var.project_identifier}\""
              }
            }]
          }
        }
      },
    ]

    # Additional kinds — pull-request, workflow, workflow-run,
    # dependabot-alert, code-scanning-alert — are added once the
    # blueprints they map onto are decided. They are the input to the
    # DORA-style delivery metrics and to the security dimension of the
    # scorecard, so they arrive in Phase 4, not now. Adding a kind
    # before its blueprint exists produces failed-transform counters,
    # not data.
  })
}

output "github_integration_id" {
  description = "Port's internal id for the adopted GitHub integration."
  value       = port_integration.github.id
}

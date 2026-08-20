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
# Seeing that error means the import step was skipped, not that this
# mapping needs a fix. Run the import and re-plan.
#
# installation_app_type IS declared below, and it is NOT only a
# create-path field. The provider is create-and-override: it sends
# every attribute on update, including nil for attributes absent from
# the HCL. Undeclared, it blanks the live "github-ocean" value —
# confirmed in the plan diff on 20 Aug 2026, which read
# `installation_app_type = "github-ocean" -> null`. See
# integrationToPortBody.go in the provider source.
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
  installation_id       = var.github_installation_id
  installation_app_type = "github-ocean"
  title                 = "GitHub — Mayo pilot"

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
    # false: do not auto-delete Port entities when their source entity
    # disappears. During the pilot, mappings and repo filters are still
    # being adjusted; a narrowed filter or a renamed repo should not
    # silently destroy catalog entries. Orphans are visible and can be
    # cleaned up deliberately. This is risk area 1 in project-policy.md.
    deleteDependentEntities = false

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
                #
                # FIXED. This was `.language // "other" | ascii_downcase`,
                # which lowercases GitHub's language name and hands it
                # straight to a closed enum. Measured:
                #
                #   "C#"         -> "c#"      not in the enum
                #   "C++"        -> "c++"     not in the enum
                #   "TypeScript" -> "typescript"   fine
                #
                # `service.language` permits exactly typescript,
                # javascript, python, php, go, java, csharp, other. So a
                # single C# repository in the pilot produced a rejected
                # entity, and FR-008 requires the failed counter to be
                # ZERO — one C# repo made that criterion unreachable
                # while looking like a data problem rather than a
                # mapping bug.
                #
                # An explicit lookup with an `other` fallback is what
                # makes the enum closed on our side instead of hoping
                # GitHub's vocabulary matches ours. Anything unlisted —
                # Rust, Kotlin, Scala, C++ — lands in `other`, which is
                # a value the enum actually has.
                language = "(.language // \"other\" | ascii_downcase) as $l | {\"c#\":\"csharp\",\"csharp\":\"csharp\",\"typescript\":\"typescript\",\"javascript\":\"javascript\",\"python\":\"python\",\"php\":\"php\",\"go\":\"go\",\"java\":\"java\"}[$l] // \"other\""

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
      {
        # Pull requests -> our own `pull_request` blueprint. Ocean's
        # default `githubPullRequest` stays OFF. FR-005 forbids an
        # integration-CREATED blueprint; a custom one we point the
        # mapping at does not violate that rule, which is the whole
        # basis of the FR-015 decision.
        #
        # states: ["open"] deliberately, and it is Ocean's own default.
        # Open pull requests are a bounded working set. Merged history
        # is the unbounded one, and it is what makes G-9 (Port's
        # per-blueprint entity limit) a live question rather than a
        # theoretical one. Merged history is also a Phase 4 DORA input,
        # not a Phase 2 one — see the note at the end of this array.
        #
        # DO NOT widen this to ["open","closed"] until G-9 has a
        # written answer from Port support. It is a one-line change and
        # that is exactly why it needs the gate stated here.
        #
        # The live tenant carried a SECOND, richer pull-request block
        # (states ["closed"], since 90, maxResults 300, selector
        # `.base.ref == "main" and .state == "closed" and
        # .merged_at != null`) feeding a `deployment` blueprint. It is
        # deliberately NOT adopted here, and this is the decision, not
        # an oversight:
        #
        #   - It was Ocean default-resource output, not something a
        #     human wrote for Mayo. Nothing in the spec asks for it.
        #   - `deployment` is not one of the nine blueprints in the
        #     shared model, so adopting the block means adopting a
        #     blueprint FR-005 forbids an integration from creating.
        #   - Its `service` relation searched the property
        #     `github_repository_id`, which no blueprint in this model
        #     defines. That is the exact cause of the live
        #     "filter on non exists properties is not supported"
        #     failures — the mapping could never have worked here.
        #   - `states ["closed"]` + `since 90` is precisely the
        #     unbounded merged history the G-9 gate above holds back.
        #
        # Merged history returns in Phase 4, through this block's
        # `status` expression, once G-9 has a written answer and a
        # `deployment` blueprint is a decided part of the model.
        kind = "pull-request"
        selector = {
          query  = "true"
          states = ["open"]
        }
        port = {
          entity = {
            mappings = [{
              # .__repository is injected by Ocean and resolves to the
              # repository NAME as a string — the same value the
              # `repository` kind above uses as its service identifier
              # (".name"). That is what makes the relation below line
              # up without a lookup.
              identifier = ".__repository + \"-\" + (.number|tostring)"
              title      = ".title"
              blueprint  = "\"pull_request\""
              properties = {
                # The provider's .state is open|closed only. "merged"
                # is .merged_at being non-null. Mapping .state straight
                # through would render every merged pull request as
                # "closed", which is wrong on the one transition the
                # exit test is about.
                status = "if .merged_at then \"merged\" elif .state == \"open\" then \"open\" else \"closed\" end"

                # .html_url is the browser link. Ocean's default sample
                # uses .url, which is the API URL — not clickable for a
                # human, and this blueprint exists to be looked at.
                url        = ".html_url"
                author     = ".user.login"
                created_at = ".created_at"
                updated_at = ".updated_at"
                merged_at  = ".merged_at"
                closed_at  = ".closed_at"
                pr_number  = ".number"
              }
              relations = {
                # ADR-002: service, not repository. Nothing creates
                # repository entities.
                service = ".__repository"
              }
            }]
          }
        }
      },
    ]

    # Additional kinds — workflow, workflow-run, dependabot-alert,
    # code-scanning-alert — are added once the blueprints they map onto
    # are decided. They are the input to the DORA-style delivery metrics
    # and to the security dimension of the scorecard, so they arrive in
    # Phase 4, not now. Adding a kind before its blueprint exists
    # produces failed-transform counters, not data.
    #
    # `pull-request` landed in Phase 2 (FR-015) because the phase exit
    # test names it explicitly. Merged-PR history stays a Phase 4
    # concern — see the states filter above.
  })
}

output "github_integration_id" {
  description = "Port's internal id for the adopted GitHub integration."
  value       = port_integration.github.id
}

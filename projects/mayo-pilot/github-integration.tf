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

  # OCEAN'S OWN DEFAULT MAPPING, adopted verbatim, with one correction.
  #
  # REVERTED 20 Aug 2026 at the user's explicit request, reversing
  # ADR-003. The catalog is to show GitHub Repositories, GitHub Users,
  # GitHub Workflows and the rest — Ocean's vendor-named blueprints —
  # rather than redirecting a repository onto our own `service`.
  #
  # WHAT THIS COSTS, stated plainly so the next reader does not have to
  # rediscover it:
  #
  #   - `service` and `pull_request` stop being written. They held 25 and
  #     2 entities respectively before this revert; those become orphans
  #     (deleteDependentEntities is false, so they are not deleted).
  #   - FR-015's exit test is no longer met by this mapping. Its
  #     `pull_request` blueprint still exists and is still declared in
  #     modules/, but nothing populates it.
  #   - FR-005 fails, and stays failing: every blueprint targeted here is
  #     integration-created, which is what that requirement forbids.
  #   - T-1 is broken at the mapping layer. Every target blueprint names
  #     a git vendor, so swapping GitHub for Azure DevOps means a new set
  #     of blueprints rather than a new mapping onto the same ones.
  #
  # ADR-003 is not deleted. It records why the opposite decision was
  # taken and what evidence supported it; this block records that a human
  # overrode it. Reversing again means restoring the two-block mapping
  # from that ADR.
  #
  # THE ONE CORRECTION. Three of Ocean's blocks — githubPullRequest,
  # githubWorkflowRun and deployment — resolve a `service` relation by
  # searching `property: "github_repository_id"`. No blueprint in this
  # model defines that property, and that is precisely the error the Port
  # UI reported all morning:
  #
  #   filter on non exists properties is not supported
  #
  # Those three relations are stripped. Adding `github_repository_id` to
  # the shared `service` blueprint was the alternative and is rejected:
  # it would name a git vendor in the shared model (T-1) to satisfy a
  # mapping this repository did not write, and `service` is no longer
  # written by this integration anyway, so the relation could never
  # resolve.
  #
  # The mapping lives in github-ocean-default-mapping.json rather than
  # inline. It is 300 lines of vendor-supplied jq that nobody here
  # authored or should hand-edit; keeping it as data makes that obvious
  # and keeps this file reviewable. Terraform still owns it — a UI edit
  # is still reverted on the next apply.
  config = jsonencode(merge(
    jsondecode(file("${path.module}/github-ocean-default-mapping.json")),
    {
      createMissingRelatedEntities = false

      # false: orphan rather than destroy. This revert alone strands 27
      # entities under `service` and `pull_request`; true would delete
      # them silently. Risk area 1 in project-policy.md.
      deleteDependentEntities = false

      # Mapping lives here, not in the org's .github-private repo. Two
      # sources of mapping truth is the same failure mode as UI +
      # Terraform.
      repoManagedMapping = false
    },
    var.github_repository_type == null ? {} : {
      repositoryType = var.github_repository_type
    },
    var.github_repo_search == null ? {} : {
      repoSearch = var.github_repo_search
    },
    var.github_organizations == null ? {} : {
      organizations = var.github_organizations
    },
  ))
}

output "github_integration_id" {
  description = "Port's internal id for the adopted GitHub integration."
  value       = port_integration.github.id
}

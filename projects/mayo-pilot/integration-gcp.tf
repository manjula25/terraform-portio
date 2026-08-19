####################################################################
# Google Cloud (Ocean) integration mapping, as code.
#
# Same import-before-apply pattern as github-integration.tf — read
# that file's header first; only the GCP-specific differences are
# stated here. Install the integration in the Port UI, then adopt:
#
#   terraform import port_integration.gcp <installation-id>
#
# The provider is create-and-override; one owner per entity. This
# file is the owner of the GCP mapping.
#
# GATES — apply only after both close (../../prd-open-questions.md):
#   PQ-1  — how data leaves Mayo's network. Assumes Port reaches in;
#           if security requires a collector, the mapping stays, the
#           plumbing changes.
#   PQ-17 — VPC Service Controls can block the hosted integration
#           even with correct IAM roles.
#
# BS-14: viewer-level read per GCP project, never folder/org. Key
# set at install time, never in this file or Terraform state.
####################################################################

locals {
  # Derive stage from the GCP project display name per IRIS d/t/s/p.
  # Splits on "-", finds the first single-character segment, maps it.
  # Returns "unknown" on no match — fails the blueprint's enum
  # validation and lands in the failed-transform counter, making the
  # error visible rather than silently guessing (M-2).
  #
  # PLACEHOLDER — confirm against real Mayo project names before
  # applying. If the convention is a prefix, suffix, or label rather
  # than a dash-segment, this expression and the identifier mapping
  # below change with it.
  gcp_stage_jq = "(.display_name | ascii_downcase | split(\"-\")) | map(select(length == 1)) | first | {d:\"dev\",t:\"test\",s:\"stage\",p:\"prod\"}[.] // \"unknown\""
}

####################################################################
# Writer transition — run this sequence when the integration goes
# live. It replaces the hand-declared `port_entity.environment`
# resources in main.tf with integration-owned entities. Two writers
# for the same record type is the blocking defect class
# (project-policy.md §Risk area 2); the identifier mapping below
# matches the hand-declared convention so step 6 replaces, not
# duplicates (FR-013).
#
# 1. Install in Port UI: service account key, createDefaultResources
#    OFF, scope to pilot projects.  Done: integration visible in UI.
# 2. terraform import port_integration.gcp <installation-id>
#    Done: resource in state, plan shows no diff on the integration.
# 3. terraform plan — verify the mapping shows intended creates only.
#    Done: plan shows creates for each pilot stage, zero destroys.
# 4. terraform state rm port_entity.environment["<stage>"] for each
#    hand-declared stage.  Done: state list shows no environment
#    entities; the entities still exist in Port (orphaned, not
#    destroyed).
# 5. Remove the port_entity.environment block from main.tf.
#    Done: grep finds no port_entity.environment in main.tf.
# 6. terraform apply — the integration creates entities with the
#    same identifiers.  Done: each stage exists once in Port, owned
#    by the integration.
####################################################################
resource "port_integration" "gcp" {
  installation_id = var.gcp_installation_id
  title           = "Google Cloud — Mayo pilot"

  config = jsonencode({
    createMissingRelatedEntities = false
    deleteDependentEntities      = true

    resources = [
      {
        # GCP Project -> our `environment` blueprint, not Ocean's
        # `gcpProject`. A parallel blueprint splits the catalog —
        # same reason GitHub maps to `service`, not `githubRepository`.
        # Requires createDefaultResources OFF at install time, or
        # Ocean's own blueprints land first and collide.
        kind = "cloudresourcemanager.googleapis.com/Project"
        selector = {
          # Start narrow — pilot projects only. Widening is a one-line
          # PR; unwinding a full-org sync that created environments
          # for stages that don't exist is not.
          query = var.gcp_project_filter
        }
        port = {
          entity = {
            mappings = [{
              # Matches the hand-declared convention
              # (${project_identifier}-${stage}) so the writer
              # transition replaces FR-003's entities, not duplicates.
              identifier = "\"${var.project_identifier}-\" + (${local.gcp_stage_jq})"
              title      = ".display_name"
              blueprint  = "\"environment\""
              properties = {
                stage = local.gcp_stage_jq
                cloud = "\"gcp\""

                # GCP projects are global; region lives in labels if
                # the pilot set it. "unknown" is an honest placeholder
                # a scorecard can flag.
                region = ".labels.region // \"unknown\""

                # P-11 / O-7: settles the GCP-project-vs-Port-project
                # collision with data. .name is the full resource
                # path; last segment is the project number. Verify
                # whether the project ID string is a separate field
                # during installation.
                cloud_project_id = ".name | split(\"/\") | last"
              }
              relations = {
                project = "\"${var.project_identifier}\""
              }
            }]
          }
        }
      },
    ]

    # Cloud Run, GKE, Cloud Functions arrive in Phase 4 with the
    # `workload` blueprint (BS-13). Adding a kind before its blueprint
    # exists produces failed-transform counters, not data.
  })
}

output "gcp_integration_id" {
  description = "Port's internal id for the adopted GCP integration."
  value       = port_integration.gcp.id
}

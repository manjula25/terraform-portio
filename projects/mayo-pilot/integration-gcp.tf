####################################################################
# Google Cloud (Ocean) integration mapping, as code.
#
# NOT THE SAME AS GITHUB. The GCP integration is self-hosted, not
# "hosted by Port" (VB-1e). There is no UI install page. The
# integration runs as a container/job on your infrastructure and
# authenticates to Port using PORT_CLIENT_ID / PORT_CLIENT_SECRET.
#
# Four deployment methods (Port docs): Helm (scheduled), CI/CD
# (scheduled), Docker (one-time), Terraform (real-time). Port's own
# recommendation is Helm/scheduled for the FIRST sync, then switch to
# the Terraform method for real-time. Live events are only available
# on the Terraform deployment.
#
# VB-1e's open question — "does port_integration apply to self-hosted
# integrations at all?" — is now ANSWERED: YES, and
# `installation_id` is the identifier WE CHOOSE at deploy time, not a
# Port-generated number.
#
#   - The provider documents installation_id as "The installation ID
#     of the integration. Must contain only lowercase letters,
#     numbers, and dashes (pattern: ^[a-z0-9-]+$)", and its own
#     example uses a self-chosen slug, "my-custom-integration-id".
#   - A self-hosted deployment sets exactly that value as the Helm
#     parameter `integration.identifier` (e.g. "ocean-custom").
#
# So the value of var.gcp_installation_id and the deployment's
# `integration.identifier` MUST BE THE SAME STRING. If they differ,
# the import in step 2 below adopts nothing and the apply creates a
# second, empty integration beside the real one.
#
# This is NOT a difference from GitHub, contrary to what this comment
# claimed until 20 Aug 2026. It was corrected by reading the live
# tenant:
#
#   GET /v1/integration          -> installationId "github-ocean"
#   GET /v1/integration/github-ocean -> 200
#   GET /v1/integration/154905752    -> 404
#
# 154905752 is the GitHub *App* installation ID — a GitHub-side number,
# not a Port object. Port's own identifier for that integration is the
# slug "github-ocean". So BOTH integrations key off a lowercase-dash
# identifier, and neither is a Port-generated number. See
# docs/work/PHASE2/implementation-plan-fr-013.md.
#
# The provider is create-and-override; one owner per entity. This
# file is the owner of the GCP mapping. Port's Terraform docs state
# the consequence of getting import wrong explicitly: "make sure your
# resource definitions match the schema of your resources in Port. If
# they don't, your state will be deleted in the next terraform
# apply."
#
# GATES — apply only after both close (../../prd-open-questions.md):
#   PQ-1  — how data leaves Mayo's network. VB-1e partially answers
#           this: GCP is always self-hosted, so the data flow is
#           always "collector pushes out." The remaining question is
#           whether the collector runs inside Mayo's VPC-SC perimeter
#           or outside it.
#   PQ-17 — VPC Service Controls can block the collector from
#           reaching the Cloud Asset Inventory API if it runs outside
#           the perimeter. Confirmed as the right question: Port's
#           GCP integration reads the Cloud Asset Inventory API for
#           every resource kind, so VPC-SC is on the critical path,
#           not adjacent to it.
#
# BS-14: viewer-level read per GCP project, never folder/org. The
# service account key is set in the self-hosted integration's config
# (Helm values, Docker env, or Terraform variables), never in this
# file or Port Terraform state. Helm also supports Workload Identity,
# which is preferable — it removes the key entirely.
####################################################################

locals {
  # Derive stage from the GCP project display name per IRIS d/t/s/p.
  # Splits on "-", finds the first single-character segment, maps it.
  # Returns "unknown" on no match — which fails the blueprint's stage
  # enum, lands in the failed-transform counter, and so makes the
  # miss visible rather than silently guessing (M-2).
  #
  # FIXED. The previous form ended `| first | {d:"dev",...}[.] //
  # "unknown"`, which did NOT return "unknown" on no match — it
  # ABORTED:
  #
  #   $ echo '{"display_name":"iris-prod"}' | jq -r '<old expression>'
  #   jq: error (at <stdin>:1): Cannot index object with null
  #
  # `first` yields null when no segment is single-character, and
  # indexing an object with null is a jq error, not a null result, so
  # the `// "unknown"` fallback was never reached. Any pilot project
  # whose name does not happen to carry a d/t/s/p segment — including
  # the plausible "iris-prod" — would have failed with a jq error
  # instead of the visible enum failure the comment promised. Binding
  # `first` to $seg and defaulting it BEFORE the index is what makes
  # the documented behaviour actually happen.
  #
  # Verified against iris-{d,t,s,p}-app, IRIS-D-App, iris-prod,
  # iris-x-app, iris, an empty display_name, and a document with no
  # display_name key at all.
  #
  # PLACEHOLDER — confirm against real Mayo project names before
  # applying. If the convention is a prefix, suffix, or label rather
  # than a dash-segment, this expression and the identifier mapping
  # below change with it.
  gcp_stage_jq = "(.display_name // \"\" | ascii_downcase | split(\"-\") | map(select(length == 1)) | first) as $seg | {d:\"dev\",t:\"test\",s:\"stage\",p:\"prod\"}[$seg // \"\"] // \"unknown\""
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
# 0. Choose the integration identifier and set it as
#    var.gcp_installation_id. Every later step reuses this one
#    string.  Done: the value is in the gitignored terraform.tfvars.
# 1. Deploy the GCP integration, Helm/scheduled first per Port's own
#    recommendation. Pass `integration.identifier` equal to step 0's
#    value, and `createPortResourcesOrigin=Empty` so Ocean registers
#    the integration WITHOUT creating its default `gcpProject` and
#    `gcpCloudResource` blueprints — that suppression is what keeps
#    FR-005 passing. Do NOT use `initializePortResources=false` for
#    this; Port's docs name it legacy and say to use
#    createPortResourcesOrigin instead. Credentials go in the
#    deployment config, never here.
#    Done: integration running, first sync completes, and the Port
#    blueprint list still contains no gcp* blueprint.
# 2. terraform import port_integration.gcp <the step 0 identifier>
#    port_integration does apply to self-hosted integrations — see the
#    header.  Done: resource in state, plan shows no diff.
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
        # Ocean's default mapping for this same kind targets
        # '"gcpProject"'; overriding the blueprint here is what
        # redirects it. Suppressing the default blueprint itself is a
        # deployment-config concern (createPortResourcesOrigin=Empty,
        # step 1 above), not a UI toggle (VB-1e).
        #
        # Kind identifier confirmed against Port's published default
        # GCP mapping.
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
                # collision with data.
                #
                # CORRECTED. This previously read
                # `.name | split("/") | last`, which is the project
                # NUMBER, not the project ID: Cloud Asset Inventory
                # returns `.name` as the full asset path
                # (//cloudresourcemanager.googleapis.com/projects/<number>).
                # Storing a number here would defeat the whole point of
                # the property, which is that a human can read it and
                # know which GCP project is meant.
                #
                # `.display_name` is the field Ocean's own default
                # mapping uses as the project's title, and is the
                # human-readable project name. STILL TO CONFIRM on the
                # first real sync: whether display_name equals the
                # project ID exactly, or whether Cloud Asset Inventory
                # exposes the ID as a separate field. Verify against
                # raw sync data before widening the filter.
                cloud_project_id = ".display_name"
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

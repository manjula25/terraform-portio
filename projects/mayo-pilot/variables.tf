variable "port_base_url" {
  description = "Port API base URL. Must match the organization stack. See organization/variables.tf."
  type        = string
  default     = "https://api.port.io"
}

####################################################################
# Project identity
####################################################################

variable "project_identifier" {
  description = "Stable identifier for the Port project entity. Never renamed once services relate to it."
  type        = string
}

variable "project_title" {
  description = "Human-readable project name, as leadership refers to it."
  type        = string
}

variable "client" {
  description = "Client or business unit this project belongs to."
  type        = string
}

variable "tier" {
  description = "Engagement classification."
  type        = string
  default     = "client"

  validation {
    condition     = contains(["internal", "client", "strategic"], var.tier)
    error_message = "tier must be one of: internal, client, strategic."
  }
}

variable "owning_team" {
  description = <<-EOT
    The Port team that owns this project. Assigned once here; services
    and environments inherit it through the project relation. Must
    already exist in Port (teams come from the IdP, not from this
    stack).
  EOT
  type        = string
}

variable "repo_url" {
  description = "Primary repository or GitHub org URL for the project."
  type        = string
  default     = null
}

variable "teams_channel" {
  description = "Microsoft Teams channel URL for the project."
  type        = string
  default     = null
}

variable "start_date" {
  description = "Engagement start date, RFC3339 (e.g. 2026-09-01T00:00:00Z)."
  type        = string
  default     = null
}

variable "environments" {
  description = <<-EOT
    The stages this project actually deploys to, keyed by stage. One
    entry per running stage and no others: an environment entity with
    nothing deployed to it is scored by S-1 as if it were real
    (FR-003). cloud_project_id records the GCP project this
    environment IS — not the Port project (O-7, P-11).

    Cloud is not a per-entry field here: FR-013/BD-2/P-11 make this
    pilot GCP-only, so it is hardcoded "gcp" on the resource rather
    than a knob on this variable. The blueprint's own cloud enum
    (aws/azure/gcp/on-prem) stays flexible for later clients.
  EOT
  type = map(object({
    title            = string
    stage            = string
    region           = string
    cloud_project_id = string
  }))

  validation {
    condition     = alltrue([for e in var.environments : contains(["dev", "test", "stage", "prod"], e.stage)])
    error_message = "stage must be one of: dev, test, stage, prod (DM-2, corrected by IR-4)."
  }
}

####################################################################
# GitHub (Ocean) integration
####################################################################

variable "github_installation_id" {
  description = <<-EOT
    The installation ID of the GitHub (Ocean) data source, taken from
    the Port UI after the integration is installed. Lowercase letters,
    numbers and dashes only.

    Terraform does not install the integration. It adopts the mapping
    of an integration that already exists, via `terraform import`. See
    docs/github-ocean-setup.md.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.github_installation_id))
    error_message = "github_installation_id must contain only lowercase letters, numbers and dashes."
  }
}

variable "github_organizations" {
  description = <<-EOT
    GitHub organizations to ingest from. NULL means "do not send it",
    which is correct when the account is a personal user rather than an
    organisation, and lets Ocean use the App-installation list.
  EOT
  type        = list(string)
  default     = null
  nullable    = true
}

variable "github_repo_search" {
  description = <<-EOT
    GitHub repository search query narrowing what is ingested. Start
    narrow — one pilot team's repos — and widen once the ingestion
    counters look clean. Ingesting the whole org on day one buries the
    pilot in repositories nobody owns.

    Example: "org:mayo-clinic topic:port-pilot"

    NULL means "do not send repoSearch at all", which makes Ocean
    enumerate the repositories the GitHub App is installed on instead of
    calling GitHub's search API. That is the reliable source for a pilot
    — see the comment in github-integration.tf.
  EOT
  type        = string
  default     = null
  nullable    = true
}

####################################################################
# Google Cloud (Ocean) integration
#
# Blocked on PQ-1 (how data leaves Mayo's network) and PQ-17 (VPC
# Service Controls reachability). Do not set these variables until
# both questions are closed and the GCP integration is deployed.
# See integration-gcp.tf header for the full gate list.
#
# NOTE (VB-1e): The GCP integration is self-hosted, not "hosted by
# Port." There is no UI install. port_integration DOES apply to
# self-hosted integrations — that question is closed. See the header
# of integration-gcp.tf for the evidence and the one catch.
####################################################################

variable "gcp_installation_id" {
  description = <<-EOT
    The identifier of the Google Cloud (Ocean) integration.

    Unlike GitHub's, this is NOT generated by Port. The GCP
    integration is self-hosted, so you choose this string yourself and
    hand it to the deployment: it must equal the Helm/Docker
    `integration.identifier` value the collector runs with. If the two
    differ, `terraform import` adopts nothing and the next apply
    creates a second, empty integration alongside the real one.

    Pick it once, before deploying anything, and keep it boring —
    "mayo-pilot-gcp" rather than anything encoding a stage or a date,
    because renaming it later means re-importing.

    The service account key is set in the self-hosted integration's
    deployment config (Helm values, Docker env, or Terraform
    variables), never in this file or Port Terraform state. Prefer
    Workload Identity on Helm, which removes the key entirely. See
    BS-14 for the access scope: viewer-level read per GCP project,
    never at folder or organisation level.
  EOT
  type        = string

  validation {
    # The provider's own documented pattern for installation_id.
    condition     = can(regex("^[a-z0-9-]+$", var.gcp_installation_id))
    error_message = "gcp_installation_id must contain only lowercase letters, numbers and dashes (the provider's documented pattern for installation_id)."
  }
}

variable "gcp_project_filter" {
  description = <<-EOT
    JQ expression filtering which GCP projects are ingested. Start
    narrow — the pilot's projects only — and widen once the ingestion
    counters look clean. Ingesting every project in the org creates
    environments for stages that don't exist in the pilot.

    Examples:
      ".display_name | startswith(\"iris-\")"
      ".labels.port-pilot == \"true\""
  EOT
  type        = string
}

variable "github_repository_type" {
  description = <<-EOT
    Which repositories the GitHub integration ingests: "private", "public",
    or "all".

    DEFAULTS TO "private" AND SHOULD STAY THERE FOR MAYO. A HIPAA/HITRUST
    organisation has no business pulling public forks into the catalog.

    Override it only in a sandbox, and only in the gitignored
    terraform.tfvars. The pilot sandbox has no private repository that
    GitHub's search API returns to the installed App, so "private" there
    yields zero entities — a silent empty result, not an error.
  EOT
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.github_repository_type == null || contains(["private", "public", "all"], var.github_repository_type)
    error_message = "github_repository_type must be one of: private, public, all."
  }
}

####################################################################
# The mayo-pilot project stack.
#
# Owned by this project's lead. Adding the next project means copying
# this directory, not editing anything under modules/. That copy is the
# mechanism that makes project six fast.
#
# Phase 2 order matters:
#   1. this project entity, with the owning team assigned  <- here
#   2. GitHub (Ocean) connected, ingestion counters watched
#   3. environments, one per running stage
#   4. services, related to project and environments
#   5. one self-service action that removes a real ticket
####################################################################

####################################################################
# 1. The project entity. The tenancy boundary.
#
# `teams` is set here and ONLY here. environment and service inherit
# ownership through their project relation, so setting a team on them
# is both redundant and a second place for it to drift.
####################################################################
resource "port_entity" "project" {
  identifier = var.project_identifier
  title      = var.project_title
  blueprint  = "project"

  teams = [var.owning_team]

  properties = {
    string_props = merge(
      {
        "client" = var.client
        "status" = "active"
        "tier"   = var.tier
      },
      var.repo_url == null ? {} : { "repo_url" = var.repo_url },
      var.teams_channel == null ? {} : { "teams_channel" = var.teams_channel },
      var.start_date == null ? {} : { "start_date" = var.start_date },
    )
  }
}

####################################################################
# 3. Environments, one per running stage.
#
# Only the stages that actually exist. An environment entity with
# nothing deployed to it is a lie the scorecard will later reward.
####################################################################
locals {
  environments = {
    dev = {
      title  = "Pilot — Dev"
      stage  = "dev"
      region = "us-central1"
    }
    production = {
      title  = "Pilot — Production"
      stage  = "production"
      region = "us-central1"
    }
  }
}

resource "port_entity" "environment" {
  for_each = local.environments

  identifier = "${var.project_identifier}-${each.key}"
  title      = each.value.title
  blueprint  = "environment"

  properties = {
    string_props = {
      "stage"  = each.value.stage
      "cloud"  = "gcp"
      "region" = each.value.region
    }
  }

  relations = {
    single_relations = {
      "project" = port_entity.project.identifier
    }
  }
}

####################################################################
# 4. Services.
#
# Registered by hand for the pilot handful. If the pilot turns out to
# be monorepo-heavy, this becomes mapping config in the GitHub Ocean
# integration instead of entities here (open point O-6: the plan
# assumes one repo equals one service).
#
# Left as a worked example rather than invented service names — fill in
# from the pilot repo list once the pilot is named (Phase 0).
####################################################################
# resource "port_entity" "example_service" {
#   identifier = "pilot-api"
#   title      = "Pilot API"
#   blueprint  = "service"
#
#   properties = {
#     string_props = {
#       "language"        = "typescript"
#       "lifecycle"       = "production"
#       "repo_url"        = "https://github.com/<org>/pilot-api"
#       "readme_url"      = "https://github.com/<org>/pilot-api#readme"
#       "on_call_channel" = "https://teams.microsoft.com/l/channel/..."
#     }
#     boolean_props = {
#       "has_healthcheck" = true
#     }
#   }
#
#   relations = {
#     single_relations = {
#       "project" = port_entity.project.identifier
#     }
#     many_relations = {
#       "environment" = [for k, e in port_entity.environment : e.identifier]
#     }
#   }
# }

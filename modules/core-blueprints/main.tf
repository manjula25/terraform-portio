####################################################################
# Core shared data model
#
# Three blueprints form the backbone reused across every project:
#   project      -> the tenancy boundary (a client engagement)
#   environment  -> a deployment target belonging to a project
#   service      -> a deployable unit belonging to a project
#
# Apply this once to the organization. Per-project entities,
# integrations, and permissions are layered on top in separate stacks.
#
# This file is the promoted copy of "blueprints (1).tf" from the
# planning kit, unchanged. The two model gaps the plan requires to be
# closed BEFORE the pilot registers services are still open and are
# marked TODO below:
#
#   O-5  service.kind (web | mobile | api) plus kind-specific fields
#   O-1  a team blueprint related to ai_usage
#
# They are deliberately not invented here. Closing them is a model
# decision that must land in mayo-port-implementation-plan.md and
# understanding.md at the same time.
####################################################################

####################################################################
# Project: top-level grouping and tenancy boundary
####################################################################
resource "port_blueprint" "project" {
  identifier  = "project"
  title       = "Project"
  icon        = "Blueprint"
  description = "A client engagement or internal initiative. The tenancy boundary for the portal."

  properties = {
    string_props = {
      "client" = {
        title       = "Client"
        description = "Client or business unit this project belongs to."
        required    = true
      }
      "status" = {
        title    = "Status"
        required = true
        enum     = ["active", "paused", "completed", "archived"]
      }
      "tier" = {
        title       = "Tier"
        description = "Engagement classification."
        enum        = ["internal", "client", "strategic"]
      }
      "repo_url" = {
        title  = "Repository"
        format = "url"
      }
      "teams_channel" = {
        title  = "Teams Channel"
        format = "url"
      }
      "start_date" = {
        title  = "Start Date"
        format = "date-time"
      }
    }
  }

  # Assign an owning team directly at the project level. Services and
  # environments inherit ownership from here.
  ownership = {
    type = "Direct"
  }
}

####################################################################
# Environment: a deployment target belonging to a project
####################################################################
resource "port_blueprint" "environment" {
  identifier  = "environment"
  title       = "Environment"
  icon        = "Environment"
  description = "A deployment stage (dev, staging, production) within a project."

  properties = {
    string_props = {
      "stage" = {
        title    = "Stage"
        required = true
        enum     = ["dev", "staging", "production"]
      }
      "cloud" = {
        title = "Cloud Provider"
        enum  = ["aws", "azure", "gcp", "on-prem"]
      }
      "region" = {
        title       = "Region"
        description = "Cloud region or datacenter for this environment."
      }
      "url" = {
        title  = "Access URL"
        format = "url"
      }
    }
  }

  relations = {
    "project" = {
      title    = "Project"
      target   = port_blueprint.project.identifier
      required = true
      many     = false
    }
  }

  ownership = {
    type = "Inherited"
    path = "project"
  }
}

####################################################################
# Service: a deployable unit belonging to a project
####################################################################
resource "port_blueprint" "service" {
  identifier  = "service"
  title       = "Service"
  icon        = "Microservice"
  description = "A microservice, application, or worker owned by a project."

  # TODO(O-5): add the "kind" enum (web, mobile, api) and the
  # kind-specific field groups discovery specifies. Scorecards are
  # expected to be kind-aware, so this must land before the pilot
  # registers services.
  properties = {
    string_props = {
      "language" = {
        title = "Language"
        enum  = ["typescript", "javascript", "python", "php", "go", "java", "csharp", "other"]
      }
      "lifecycle" = {
        title    = "Lifecycle"
        required = true
        enum     = ["experimental", "production", "deprecated"]
      }
      "repo_url" = {
        title  = "Repository"
        format = "url"
      }
      "docs_url" = {
        title  = "Documentation"
        format = "url"
      }
      "readme_url" = {
        title  = "README"
        format = "url"
      }
      "on_call_channel" = {
        title  = "On-call Teams Channel"
        format = "url"
      }
    }

    boolean_props = {
      "has_healthcheck" = {
        title       = "Has Health Check"
        description = "Whether the service exposes a health or readiness endpoint."
      }
    }
  }

  # Pull environment context onto the service through the environment relation.
  mirror_properties = {
    "env_stage" = {
      title = "Environment Stage"
      path  = "environment.stage"
    }
    "env_region" = {
      title = "Environment Region"
      path  = "environment.region"
    }
  }

  relations = {
    "project" = {
      title    = "Project"
      target   = port_blueprint.project.identifier
      required = true
      many     = false
    }
    "environment" = {
      title    = "Environment"
      target   = port_blueprint.environment.identifier
      required = false
      many     = true
    }
  }

  ownership = {
    type = "Inherited"
    path = "project"
  }
}

####################################################################
# AI Usage: a periodic token and cost record for Claude and Codex
#
# Populated on a schedule (typically daily) from the Anthropic Admin
# and Analytics APIs and the OpenAI organization usage and cost APIs,
# most likely through a Custom Ocean integration. One record per
# period per provider per team or project. The catalog holds only
# aggregate counts and cost, never prompt or completion content.
#
# Attribution depends on mirroring the provider account structure
# (Anthropic workspaces, OpenAI projects) to this project model, so
# usage maps cleanly without heuristics.
####################################################################
resource "port_blueprint" "ai_usage" {
  identifier  = "ai_usage"
  title       = "AI Usage"
  icon        = "AI"
  description = "A periodic token and cost record for an AI coding assistant, attributed to a project."

  properties = {
    string_props = {
      "provider" = {
        title    = "Provider"
        required = true
        enum     = ["claude", "codex"]
      }
      "actor_type" = {
        title       = "Actor Type"
        description = "Human seat usage attributes per user; agent usage attributes per API key, workspace, or project."
        required    = true
        enum        = ["developer_seat", "agent"]
      }
      "actor_ref" = {
        title       = "Actor Reference"
        description = "User email for a seat, or the agent or key identifier for API usage."
      }
      "surface" = {
        title       = "Surface"
        description = "Where the usage originated. Seat surfaces for humans, api for agents. No web or chat surface is in scope."
        enum        = ["claude_code", "codex_cli", "codex_cloud", "codex_review", "api"]
      }
      "model" = {
        title = "Model"
      }
      "workspace_or_project" = {
        title       = "Provider Workspace or Project"
        description = "The Anthropic workspace or OpenAI project this usage was billed through."
      }
      "period_start" = {
        title  = "Period Start"
        format = "date-time"
      }
      "period_granularity" = {
        title = "Granularity"
        enum  = ["day", "hour", "minute"]
      }
    }

    number_props = {
      "input_tokens" = {
        title = "Input Tokens"
      }
      "output_tokens" = {
        title = "Output Tokens"
      }
      "cache_read_tokens" = {
        title = "Cache Read Tokens"
      }
      "total_tokens" = {
        title = "Total Tokens"
      }
      "cost_usd" = {
        title       = "Cost (USD)"
        description = "Attributed dollar cost for this period."
      }
      "active_users" = {
        title = "Active Users"
      }
      "requests" = {
        title = "Requests"
      }
    }
  }

  relations = {
    "project" = {
      title    = "Project"
      target   = port_blueprint.project.identifier
      required = false
      many     = false
    }
    # TODO(O-1): a relation to a team blueprint is added once the team
    # model is settled (default _team blueprint or a custom one), so
    # usage can roll up per team as well as per project. Until this
    # lands, per-team AI spend is not answerable from the catalog.
  }
}

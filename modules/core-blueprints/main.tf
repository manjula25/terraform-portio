####################################################################
# Core shared data model
#
# The spine, reused across every project and every track:
#
#   project           -> the tenancy boundary (a client engagement)
#   environment       -> a deployment stage belonging to a project
#   service           -> a deployable unit belonging to a project
#   repository        -> the source repo a service is built from
#   ai_usage          -> a periodic token and cost record
#   agent             -> registry of autonomous coding agents
#   skill             -> registry of agent skills
#   mcp_server        -> registry of MCP servers
#   ingestion_source  -> freshness and health per ingestion source
#
# Apply this once to the organization. Per-project entities,
# integrations, and permissions layer on top in separate stacks.
#
# T-1: this file is track-agnostic. No property or relation identifier
# names GitHub or Azure DevOps. Enum values may name a vendor; field
# names may not.
#
# B-5: one model, many projects. Per-project difference lives in
# entities, scorecards, actions, and permissions — never in a fork of
# anything below.
#
# B-4 warning: the Port provider is create-and-override. A property
# removed from this file is deleted from the live blueprint, and its
# stored values go with it. Removals get the same scrutiny as a
# database migration, because that is what they are.
#
# Traceability: requirement IDs below are from mayo-port-prd.md.
####################################################################

locals {
  # B-6, verbatim on every registry blueprint and every registry-backed
  # view. A registry teams believe grants access is worse than no
  # registry at all.
  #
  # HARD LIMIT: Port rejects a blueprint description over 200
  # characters ("description" must NOT have more than 200 characters).
  # This sentence plus the longest prefix below must stay inside that.
  # The first version of this file was 209 and failed the apply on
  # `agent`. If you lengthen it, lengthen it for all three registries
  # and re-check, because B-6 requires the SAME sentence on each.
  registry_disclaimer = "Visibility, not enforcement: records what exists and who is approved. Does not grant, gate, or block access."
}

####################################################################
# Project — the tenancy boundary                              (DM-1)
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

      # DM-6: Jira and Confluence are LINKED, never ingested. No ticket
      # or page content enters Port — not as entities, not as
      # aggregated counts. Ticket summaries are human free text, and in
      # a clinical organisation free text is where a patient identifier
      # lands by accident. That would break B-1 and reopen the privacy
      # position G-2 rests on.
      #
      # The links sit here on `project` and not on `service` because
      # `service` is written by the git integration, and a second
      # writer risks blanking ingested fields (BD-4, BS-11).
      "jira_project_key" = {
        title       = "Jira Project Key"
        description = "Jira project key, e.g. IAIC. A link only — no issue data is ingested (DM-6)."
      }
      "jira_project_url" = {
        title  = "Jira Project"
        format = "url"
      }
      "confluence_space_url" = {
        title  = "Confluence Space"
        format = "url"
      }
    }
  }

  # DM-1: the team is assigned here, once. Services and environments
  # inherit ownership downward rather than repeating it.
  ownership = {
    type = "Direct"
  }
}

####################################################################
# Environment — a deployment stage                            (DM-2)
####################################################################
resource "port_blueprint" "environment" {
  identifier  = "environment"
  title       = "Environment"
  icon        = "Environment"
  description = "A deployment stage within a project. One Google Cloud project maps to one environment (P-11, BD-2)."

  properties = {
    string_props = {
      # DM-2, corrected by IR-4: FOUR values, not three. Mayo's estate
      # runs four separate GCP projects coded d/t/s/p, four state
      # buckets, four DNS domains. Mayo's word is "stage", not
      # "staging"; Mayo's word wins.
      "stage" = {
        title    = "Stage"
        required = true
        enum     = ["dev", "test", "stage", "prod"]
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

      # P-11 / O-7: the word collision that keeps biting. A GCP project
      # is a resource container; a Port project is a client programme;
      # a Port ORGANIZATION used as dev/prod is a third thing again
      # (G-4). Recording the source container here settles which is
      # meant, with data rather than a glossary entry.
      "cloud_project_id" = {
        title       = "Cloud Project ID"
        description = "The GCP project (or Azure subscription) this environment is. Not the Port project."
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
# Repository — the source repo behind a service               (DM-5)
#
# Resolves OQ-4. The pilot exit test is "the team can see their
# services and their pull requests" (Phase 2 exit) and no blueprint
# held either. This one holds the repository half.
####################################################################
resource "port_blueprint" "repository" {
  identifier  = "repository"
  title       = "Repository"
  icon        = "Git"
  description = "A source control repository. Metadata only — never file content (B-1, P-4)."

  properties = {
    string_props = {
      # Vendor names are legitimate as enum VALUES. T-1 forbids them
      # only in property and relation identifiers.
      "provider" = {
        title    = "Provider"
        required = true
        enum     = ["github", "azure_devops"]
      }
      "url" = {
        title  = "Repository URL"
        format = "url"
      }
      "default_branch" = {
        title = "Default Branch"
      }
      "visibility" = {
        title = "Visibility"
        enum  = ["private", "internal", "public"]
      }
      "last_activity_at" = {
        title  = "Last Activity"
        format = "date-time"
      }
    }

    boolean_props = {
      # N-3: archived flips the related service to `deprecated`. The
      # entity is NOT deleted — deletion destroys history, including AI
      # spend records finance may still need for a closed quarter, and
      # Port's cascade can remove related records without warning.
      "archived" = {
        title       = "Archived"
        description = "Archived repositories are marked deprecated, never deleted (N-3)."
      }
    }
  }

  relations = {
    "service" = {
      title    = "Service"
      target   = port_blueprint.service.identifier
      required = false
      many     = false
    }
  }

  ownership = {
    type = "Inherited"
    path = "service.project"
  }
}

####################################################################
# Service — a deployable unit                          (DM-3, DM-4)
####################################################################
resource "port_blueprint" "service" {
  identifier  = "service"
  title       = "Service"
  icon        = "Microservice"
  description = "A deployable unit owned by a project — a web app, mobile app, API, worker, or scheduled job."

  properties = {
    string_props = {
      "language" = {
        title = "Language"
        enum  = ["typescript", "javascript", "python", "php", "go", "java", "csharp", "other"]
      }

      # DM-4 (resolves O-5, corrected by IR-5). FIVE kinds, not three.
      # The IRIS estate deploys seven Cloud Run workloads including a
      # worker, two jobs, and a proxy; three kinds could not describe
      # it.
      #
      # Required, and it must land BEFORE the pilot registers services.
      # Retrofitting a required property after entities exist means
      # backfilling every one of them by hand.
      #
      # S-3: scorecard rules are kind-aware. "Production ready" means
      # something different for a mobile app than for a cron job.
      "kind" = {
        title       = "Kind"
        description = "What sort of deployable this is. Drives which scorecard rules apply (S-3)."
        required    = true
        enum        = ["web", "mobile", "api", "worker", "job"]
      }

      # P-7: everything arrives `experimental`. Ingestion cannot know a
      # service's lifecycle, and defaulting to `production` hands every
      # new repo a production scorecard it has not earned.
      "lifecycle" = {
        title    = "Lifecycle"
        required = true
        enum     = ["experimental", "production", "deprecated"]
        default  = "experimental"
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

      ################################################################
      # Kind-specific fields (DM-4).
      #
      # Port has no conditional-requirement mechanism, so these are
      # optional and prefixed by the kind that owns them. S-3 is what
      # makes them matter: a rule never applies to a kind that cannot
      # satisfy it, so an empty `mobile_platform` on an API is correct
      # rather than a gap.
      ################################################################

      # kind = web
      "web_hosting_target" = {
        title = "Web — Hosting Target"
        enum  = ["cloud_run", "app_engine", "gke", "firebase", "cloud_functions", "other"]
      }
      "web_primary_domain" = {
        title = "Web — Primary Domain"
      }
      "web_framework" = {
        title = "Web — Framework"
      }

      # kind = mobile
      "mobile_platform" = {
        title = "Mobile — Platform"
        enum  = ["ios", "android", "cross_platform"]
      }
      "mobile_store_id" = {
        title       = "Mobile — Store Identifier"
        description = "Bundle ID or application ID as published to the store."
      }
      "mobile_released_version" = {
        title = "Mobile — Released Version"
      }
      "mobile_minimum_os" = {
        title = "Mobile — Minimum OS"
      }
      "mobile_distribution" = {
        title = "Mobile — Distribution Channel"
        enum  = ["public_store", "enterprise", "internal_test", "managed_mdm"]
      }

      # kind = api
      "api_spec_url" = {
        title  = "API — Specification"
        format = "url"
      }
      "api_version" = {
        title = "API — Version"
      }
      "api_gateway" = {
        title       = "API — Gateway"
        description = "The gateway fronting this API, e.g. Apigee."
      }
      "api_auth_model" = {
        title = "API — Auth Model"
        enum  = ["oauth2", "api_key", "mtls", "service_account", "none"]
      }

      # kind = worker
      "worker_trigger_source" = {
        title = "Worker — Trigger Source"
        enum  = ["pubsub", "queue", "event", "webhook", "other"]
      }
      "worker_queue_or_topic" = {
        title = "Worker — Queue or Topic"
      }

      # kind = job
      #
      # DM-4's done-when: a job records its schedule and timezone
      # without being pushed into a free-text notes field. These are
      # the two dedicated fields that satisfy it. `job_schedule` is a
      # cron expression, which is text by nature; the point is that it
      # has a home of its own.
      "job_schedule" = {
        title       = "Job — Schedule"
        description = "Cron expression, e.g. \"0 0 * * *\"."
      }
      "job_timezone" = {
        title       = "Job — Timezone"
        description = "IANA timezone the schedule is evaluated in, e.g. America/Chicago. A cron without a timezone is ambiguous twice a year."
      }
    }

    boolean_props = {
      "has_healthcheck" = {
        title       = "Has Health Check"
        description = "Whether the service exposes a health or readiness endpoint."
      }
    }
  }

  # DM-3: mirror environment context onto the service so the data lives
  # in one place and shows in two.
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

    # DM-7: an API declares its consumers, so an API owner can see
    # which web, mobile, worker, or job consumers a change breaks.
    #
    # Self-relation. The target is the literal identifier rather than
    # port_blueprint.service.identifier, because referring to a
    # resource from inside itself is a Terraform dependency cycle.
    "consumers" = {
      title    = "Consumers"
      target   = "service"
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
# AI Usage — a periodic token and cost record        (DM-10 … DM-13)
#
# Populated daily by the ingestion pipeline (Phase 3) from the
# Anthropic Admin and Analytics APIs, the OpenAI organization usage
# and cost APIs, and — on Track B — Vertex AI and Azure OpenAI.
#
# B-1: aggregate counts and dollars only. Never a prompt, never a
# completion, never a payload.
#
# M-4: one record per provider + actor_ref + period_start, upserted
# idempotently, because backfills and retries will happen.
####################################################################
resource "port_blueprint" "ai_usage" {
  identifier  = "ai_usage"
  title       = "AI Usage"
  icon        = "AI"
  description = "A periodic token and cost record. Never summed across actor_type — see the property description (DM-10)."

  properties = {
    string_props = {
      # DM-11 (IR-3): Mayo's production AI is Vertex AI Gemini, not
      # Claude or Codex. IRIS runs five Gemini models through Vertex
      # with service-account auth, plus gpt-4.1 via Azure OpenAI as a
      # judge model. A Gemini record must be creatable without a
      # free-text provider value.
      "provider" = {
        title    = "Provider"
        required = true
        enum     = ["claude", "codex", "vertex_ai", "azure_openai"]
      }

      # DM-10 (resolves IR-1, per PD-2). THREE actor types, not two.
      # This is the most important field in the model.
      #
      #   developer_seat -> a human on Claude Code or Codex, attributed
      #                     per user email.  "Are the seats we bought
      #                     being used?"
      #   agent          -> an autonomous agent on an API key,
      #                     attributed per provider workspace/project.
      #                     "Is an agent burning $6k a month?"
      #   application    -> Mayo software spending AI on behalf of its
      #                     users — IRIS serving clinicians — attributed
      #                     per application identity (an Apigee app_id,
      #                     which already maps to a cost centre).
      #                     "What does running our software cost?"
      #
      # NEVER SUM ACROSS THESE. Adding what we spend building software
      # to what our software spends running produces a number that
      # means nothing. No view, scorecard, or alert in this repo may
      # aggregate across actor_type without splitting by it.
      "actor_type" = {
        title       = "Actor Type"
        description = "developer_seat (per user email), agent (per workspace or key), or application (per app identity). Three different cost stories — never summed into one figure (DM-10)."
        required    = true
        enum        = ["developer_seat", "agent", "application"]
      }
      "actor_ref" = {
        title       = "Actor Reference"
        description = "User email for a seat, workspace or key identifier for an agent, application identity for an application. Stored always; rendered at team granularity only until G-5 and G-8 both land (V-2)."
      }

      # DM-12: deliberately no `web` and no `chat` value. That encodes
      # Mayo's no-web-access policy into the model.
      #
      # Understand the limit and state it: a missing enum value does
      # not PREVENT the behaviour, it means you cannot see it.
      # Enforcement lives in network policy, not here.
      "surface" = {
        title       = "Surface"
        description = "Where the usage originated. No web or chat value exists, by design (DM-12) — that is a visibility limit, not an enforcement mechanism."
        enum        = ["claude_code", "codex_cli", "codex_cloud", "codex_review", "api"]
      }
      "model" = {
        title = "Model"
      }
      "workspace_or_project" = {
        title       = "Provider Workspace or Project"
        description = "The Anthropic workspace, OpenAI project, GCP project, or Azure resource this usage was billed through."
      }

      # M-5: daily buckets in UTC. "Daily" has to mean one specific
      # midnight or the same day lands twice.
      "period_start" = {
        title       = "Period Start"
        description = "Start of the usage period, in UTC (M-5)."
        format      = "date-time"
      }
      "period_granularity" = {
        title       = "Granularity"
        description = "Daily for 90 days, then monthly rollups under the same key (M-5)."
        enum        = ["minute", "hour", "day", "month"]
      }

      # M-7: where a provider cost API returns dollars, use them. Where
      # a source returns tokens only, compute from the versioned rate
      # card in this repo — and say on screen which it was (S-11).
      "cost_basis" = {
        title       = "Cost Basis"
        description = "vendor_reported = dollars from the provider's own cost API. rate_card = computed by us from the versioned rate card (M-7)."
        enum        = ["vendor_reported", "rate_card"]
      }
      "rate_card_version" = {
        title       = "Rate Card Version"
        description = "Dated rate-card entry used, when cost_basis is rate_card. Changes only by pull request (M-7, GD-7)."
      }
    }

    number_props = {
      # DM-13: these measures and no others. Trends and efficiency
      # ratios are free math on these fields; cost-per-PR is
      # attribution fantasy and is rejected.
      #
      # M-1/DM-13: a measure with no source is left NULL, never zero.
      # Null and zero are different claims, and a dashboard must not
      # read a missing source as "spent nothing".
      "input_tokens"      = { title = "Input Tokens" }
      "output_tokens"     = { title = "Output Tokens" }
      "cache_read_tokens" = { title = "Cache Read Tokens" }
      "total_tokens"      = { title = "Total Tokens" }
      "cost_usd" = {
        title       = "Cost (USD)"
        description = "Attributable cost, not billing. Null where no source exists — never zero (DM-13)."
      }
      "active_users" = { title = "Active Users" }
      "requests"     = { title = "Requests" }
    }
  }

  relations = {
    "project" = {
      title    = "Project"
      target   = port_blueprint.project.identifier
      required = false
      many     = false
    }

    # DM-8 (resolves O-1, per GD-2). The native _team blueprint, not a
    # custom one: Port's ownership and permission inheritance already
    # assume _team, and rosters arrive with SSO (DM-9).
    #
    # This is what moves "spend by team" from Blocked to Safe in §17 —
    # provided PQ-10 confirms Entra groups actually match the delivery
    # squads. If they mirror the org chart instead, per-team rollups
    # describe reporting lines rather than teams, and GD-2 reopens.
    #
    # _team is a Port system blueprint. It is referenced by literal
    # identifier because Terraform does not create or manage it.
    "team" = {
      title    = "Team"
      target   = "_team"
      required = false
      many     = false
    }

    # M-10: the shadow-agent count is "agents with spend in the period
    # whose registration state is unregistered". That question needs an
    # edge from spend to the agent registry, or it can only be answered
    # from a hand-maintained list — which GD-6 explicitly rules out.
    "agent" = {
      title    = "Agent"
      target   = port_blueprint.agent.identifier
      required = false
      many     = false
    }

    # DM-19: which ingestion run produced this record, so a stale or
    # failed source is traceable from the number it wrote.
    "ingestion_source" = {
      title    = "Ingestion Source"
      target   = port_blueprint.ingestion_source.identifier
      required = false
      many     = false
    }
  }
}

####################################################################
# Agent registry                                    (DM-14 … DM-18)
#
# GD-6's shadow-agent count needs something to be unclaimed against.
# This is that something.
#
# DM-15 / A-6: agents are AUTO-CREATED on first observed spend, flagged
# `unregistered`, with a Teams nudge to claim. The catalog builds
# itself from observed reality, and "claim your agent" is an easier ask
# than "register before you run". Registration is policy, not
# enforcement (R-2) — nothing here stops a script on a laptop.
####################################################################
resource "port_blueprint" "agent" {
  identifier  = "agent"
  title       = "Agent"
  icon        = "Robot"
  description = "An autonomous coding agent seen spending on a provider key. ${local.registry_disclaimer}"

  properties = {
    string_props = {
      "display_name" = {
        title = "Display Name"
      }
      "purpose" = {
        title       = "Purpose"
        description = "What this agent is for. Set by whoever claims it."
      }
      "provider_ref" = {
        title       = "Provider Workspace or Key Reference"
        description = "The workspace, project, or key identifier this agent was first observed on. A reference, never the key itself (G-7)."
      }
      # DM-14 / M-10: the shadow-agent count is computed from this
      # field plus spend in the period — not from a list anyone
      # maintains by hand.
      #
      # DM-18, and it must be said next to the number: this metric
      # MIS-READS shared use. An agent three teams rely on looks
      # unclaimed until exactly one of them claims it.
      "registration_state" = {
        title       = "Registration State"
        description = "unregistered until a human claims it. The shadow-agent count is agents with spend this period still marked unregistered (M-10). This mis-reads shared agents — see DM-18."
        required    = true
        enum        = ["unregistered", "claimed"]
        default     = "unregistered"
      }
      "first_seen" = {
        title  = "First Seen"
        format = "date-time"
      }
      "last_seen" = {
        title  = "Last Seen"
        format = "date-time"
      }
    }
  }

  relations = {
    # DM-17 says every registry entry has one REQUIRED owning project
    # and team, so accountability resolves to a single name.
    #
    # These are optional here, and only here, because DM-15 requires an
    # agent to be auto-created the moment unknown spend appears — and a
    # required owner would make that creation fail, which is exactly
    # the shadow agent we most need to see. Owner is unset while
    # `registration_state` is `unregistered` and set on claim.
    #
    # The conflict between DM-15 and DM-17 is real and is resolved here
    # in favour of DM-15. skill and mcp_server below keep DM-17's
    # required owner, because nothing auto-creates those.
    "project" = {
      title    = "Owning Project"
      target   = port_blueprint.project.identifier
      required = false
      many     = false
    }
    "team" = {
      title    = "Owning Team"
      target   = "_team"
      required = false
      many     = false
    }

    # DM-17: shared capability is REPRESENTABLE; cost is never split.
    # Consumers are recorded for visibility. Spend still lands wholly
    # on the owner.
    #
    # Consequence to state out loud, on screen (V-3): chargeback for a
    # shared agent lands entirely on the owning project, which can make
    # a platform team look like the organisation's biggest spender.
    # Unstated, the cut is quietly wrong. Stated, it is loudly
    # incomplete. Loudly incomplete is the acceptable one.
    "consumers" = {
      title    = "Consuming Teams"
      target   = "_team"
      required = false
      many     = true
    }
  }
}

####################################################################
# Skill registry                                             (DM-16)
#
# PD-3, resolving OQ-6: SCHEMA ONLY in Phase 1. Zero entities at the
# end of Phase 1. The user- and team-level permission model lands in
# Phase 2 (P-9), once _team is synced and the pilot supplies real
# entities to scope against.
#
# Declaring the schema now costs nothing. Retrofitting it later costs
# entities.
####################################################################
resource "port_blueprint" "skill" {
  identifier  = "skill"
  title       = "Skill"
  icon        = "Book"
  description = "A packaged agent capability. ${local.registry_disclaimer}"

  properties = {
    string_props = {
      "display_name" = { title = "Display Name" }
      "purpose" = {
        title       = "Purpose"
        description = "What this skill does, in one line."
      }
      "source_url" = {
        title  = "Source"
        format = "url"
      }
      "approval_state" = {
        title       = "Approval State"
        description = "Whether this skill is approved for use. Approval is recorded here; it is not granted here (B-6)."
        required    = true
        enum        = ["proposed", "approved", "restricted", "retired"]
        default     = "proposed"
      }
    }
  }

  relations = {
    # DM-17: required owner. Nothing auto-creates a skill, so unlike
    # `agent` there is no reason to relax this.
    "project" = {
      title    = "Owning Project"
      target   = port_blueprint.project.identifier
      required = true
      many     = false
    }
    "team" = {
      title    = "Owning Team"
      target   = "_team"
      required = false
      many     = false
    }
    "consumers" = {
      title    = "Consuming Teams"
      target   = "_team"
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
# MCP server registry                                        (DM-16)
#
# Schema only in Phase 1, same as `skill`. MCP servers are the next
# unmanaged surface an enterprise loses track of, which is why the
# schema is declared before anyone needs it.
####################################################################
resource "port_blueprint" "mcp_server" {
  identifier  = "mcp_server"
  title       = "MCP Server"
  icon        = "Server"
  description = "A Model Context Protocol server available to agents. ${local.registry_disclaimer}"

  properties = {
    string_props = {
      "display_name" = { title = "Display Name" }
      "purpose" = {
        title       = "Purpose"
        description = "What this server exposes, in one line."
      }
      "endpoint_ref" = {
        title       = "Endpoint Reference"
        description = "How the server is reached. A reference or hostname — never a credential (G-7, N-2)."
      }
      "transport" = {
        title = "Transport"
        enum  = ["stdio", "http", "sse"]
      }
      "approval_state" = {
        title       = "Approval State"
        description = "Whether this server is approved for use. Approval is recorded here; it is not granted here (B-6)."
        required    = true
        enum        = ["proposed", "approved", "restricted", "retired"]
        default     = "proposed"
      }
    }
  }

  relations = {
    "project" = {
      title    = "Owning Project"
      target   = port_blueprint.project.identifier
      required = true
      many     = false
    }
    "team" = {
      title    = "Owning Team"
      target   = "_team"
      required = false
      many     = false
    }
    "consumers" = {
      title    = "Consuming Teams"
      target   = "_team"
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
# Ingestion source — freshness per source                    (DM-19)
#
# Required by BD-8. One failing source must not block the others, and
# every cost view must show which providers are current:
# "Anthropic: today; OpenAI: last succeeded 3 days ago."
#
# Why this blueprint exists at all: the dangerous failure is not a
# missing number. It is a number that LOOKS complete and is not.
####################################################################
resource "port_blueprint" "ingestion_source" {
  identifier  = "ingestion_source"
  title       = "Ingestion Source"
  icon        = "Sync"
  description = "Health and freshness of one AI-usage ingestion source. No cost view may render stale data as current (DM-19)."

  properties = {
    string_props = {
      "source_id" = {
        title       = "Source Identifier"
        description = "Stable identifier for this source, e.g. anthropic_admin_usage."
        required    = true
      }
      "provider" = {
        title    = "Provider"
        required = true
        enum     = ["claude", "codex", "vertex_ai", "azure_openai"]
      }
      "last_attempt_at" = {
        title  = "Last Attempt"
        format = "date-time"
      }
      # M-8: each successful run stamps this. If it is older than about
      # 26 hours the heartbeat alert fires to the same Teams channel as
      # the cost anomalies, so no dashboard can go quietly stale.
      "last_success_at" = {
        title       = "Last Success"
        description = "Staleness is measured from here. Older than ~26 hours raises the heartbeat alert (M-8)."
        format      = "date-time"
      }
      "last_status" = {
        title    = "Last Status"
        required = true
        enum     = ["ok", "failed", "never_run"]
        default  = "never_run"
      }
      # B-1: a message, never a payload. An error string that echoes
      # the request body is how prompt content leaks into a catalog
      # that promised it would hold none.
      "error_summary" = {
        title       = "Error Summary"
        description = "Failure message only. Never a request or response payload (B-1)."
      }
    }

    number_props = {
      # N-5 / P-6: the three counters, visible without reading logs.
      # Any non-zero `failed` is a mapping bug, most likely an
      # unresolvable required property or relation.
      "records_transformed" = { title = "Records Transformed" }
      "records_filtered"    = { title = "Records Filtered Out" }
      "records_failed" = {
        title       = "Records Failed"
        description = "Non-zero means a mapping bug, not a data problem (P-6)."
      }
    }
  }
}

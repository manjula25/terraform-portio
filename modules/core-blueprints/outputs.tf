####################################################################
# Blueprint identifiers, exported for project stacks to relate to.
#
# Project stacks must consume these rather than hardcoding strings —
# a renamed blueprint then breaks at plan time in every stack at once,
# which is the failure you want, instead of silently creating entities
# against an identifier nobody owns.
####################################################################

output "project_blueprint" {
  description = "Identifier of the project blueprint. Project stacks relate their entities to this."
  value       = port_blueprint.project.identifier
}

output "environment_blueprint" {
  description = "Identifier of the environment blueprint."
  value       = port_blueprint.environment.identifier
}

output "service_blueprint" {
  description = "Identifier of the service blueprint."
  value       = port_blueprint.service.identifier
}

output "repository_blueprint" {
  description = "Identifier of the repository blueprint (DM-5)."
  value       = port_blueprint.repository.identifier
}

output "ai_usage_blueprint" {
  description = "Identifier of the ai_usage blueprint."
  value       = port_blueprint.ai_usage.identifier
}

output "agent_blueprint" {
  description = "Identifier of the agent registry blueprint (DM-14)."
  value       = port_blueprint.agent.identifier
}

output "skill_blueprint" {
  description = "Identifier of the skill registry blueprint (DM-16). Zero entities in Phase 1, by design."
  value       = port_blueprint.skill.identifier
}

output "mcp_server_blueprint" {
  description = "Identifier of the mcp_server registry blueprint (DM-16). Zero entities in Phase 1, by design."
  value       = port_blueprint.mcp_server.identifier
}

output "ingestion_source_blueprint" {
  description = "Identifier of the ingestion_source blueprint (DM-19)."
  value       = port_blueprint.ingestion_source.identifier
}

output "team_blueprint" {
  description = <<-EOT
    The native Port team blueprint that ai_usage and the registries relate to
    (DM-8, resolving O-1). Terraform does not create or manage it — Port
    provides it, and teams arrive by Entra sign-in sync (DM-9). Exported so
    project stacks reference one constant instead of retyping the literal.
  EOT
  value       = "_team"
}

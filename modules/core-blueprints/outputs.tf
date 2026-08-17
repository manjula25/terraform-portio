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

output "ai_usage_blueprint" {
  description = "Identifier of the ai_usage blueprint."
  value       = port_blueprint.ai_usage.identifier
}

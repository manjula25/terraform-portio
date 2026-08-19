####################################################################
# The organization stack.
#
# Applied by the platform team only. Changes here change the model for
# every project at once, which is the point and also the risk. Every
# change goes through a PR where `terraform plan` shows the blast
# radius first.
#
# Anything project-specific belongs in projects/<name>/, never here.
####################################################################

module "core_blueprints" {
  source = "../modules/core-blueprints"
}

# Applied in Phase 4, once "production ready" has been defined per
# service kind (O-5). Left commented rather than stubbed, because an
# empty scorecard module that applies cleanly reads as "done".
# module "scorecards" {
#   source            = "../modules/scorecards"
#   service_blueprint = module.core_blueprints.service_blueprint
# }

# module "actions" {
#   source = "../modules/actions"
# }

output "blueprints" {
  description = "Blueprint identifiers the project stacks build on."
  value = {
    project     = module.core_blueprints.project_blueprint
    environment = module.core_blueprints.environment_blueprint
    service     = module.core_blueprints.service_blueprint
    repository  = module.core_blueprints.repository_blueprint
    ai_usage    = module.core_blueprints.ai_usage_blueprint

    # Registries. B-6: these record what exists and who is approved.
    # They do not grant, gate, or block.
    agent      = module.core_blueprints.agent_blueprint
    skill      = module.core_blueprints.skill_blueprint
    mcp_server = module.core_blueprints.mcp_server_blueprint

    ingestion_source = module.core_blueprints.ingestion_source_blueprint

    # Native to Port, not created here (DM-8, DM-9).
    team = module.core_blueprints.team_blueprint
  }
}

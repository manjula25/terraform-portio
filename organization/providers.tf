####################################################################
# Provider configuration for the organization stack.
#
# Credentials are NEVER set here. They come from the environment:
#   PORT_CLIENT_ID
#   PORT_CLIENT_SECRET
#
# Locally, export them from your password manager. In CI they are
# GitHub Actions secrets. They are org-level credentials and must not
# appear in the repo or in a .tfvars file.
####################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    port = {
      source  = "port-labs/port-labs"
      version = "~> 2.23"
    }
  }
}

provider "port" {
  # client_id and secret are read from PORT_CLIENT_ID and
  # PORT_CLIENT_SECRET. Do not add them as arguments.
  base_url = var.port_base_url

  # Fail the plan rather than silently coerce a property to a new type.
  # A type change on a live blueprint drops the stored values.
  blueprint_property_type_change_protection = true
}

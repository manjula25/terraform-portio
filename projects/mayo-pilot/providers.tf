####################################################################
# Provider configuration for the mayo-pilot project stack.
#
# Duplicated from organization/providers.tf on purpose. Each stack has
# its own state and its own `terraform init`, so a single root-level
# providers.tf cannot be shared across them. See the note in
# ../../README.md about this deviation from plan section 4.
#
# Credentials come from PORT_CLIENT_ID / PORT_CLIENT_SECRET.
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
  base_url                                  = var.port_base_url
  blueprint_property_type_change_protection = true
}

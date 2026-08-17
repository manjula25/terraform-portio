terraform {
  required_version = ">= 1.6.0"

  required_providers {
    port = {
      source  = "port-labs/port-labs"
      version = "~> 2.23"
    }
  }
}

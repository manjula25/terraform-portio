variable "port_base_url" {
  description = <<-EOT
    Port API base URL. This is region-specific and getting it wrong
    points Terraform at the wrong tenant.

      EU (app.port.io) -> https://api.port.io
      US (app.us.port.io) -> https://api.us.port.io

    The legacy *.getport.io hostnames still resolve but the *.port.io
    form is the documented one. Phase 0 open item "Confirm US Port
    instance" decides this value; it also decides the data-residency
    story, so do not guess it.
  EOT
  type        = string
  default     = "https://api.us.port.io"

  validation {
    condition     = can(regex("^https://api\\.(us\\.)?(get)?port\\.io$", var.port_base_url))
    error_message = "port_base_url must be https://api.port.io or https://api.us.port.io (or the legacy getport.io equivalents)."
  }
}

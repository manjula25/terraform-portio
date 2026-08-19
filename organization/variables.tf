variable "port_base_url" {
  description = <<-EOT
    Port API base URL. This is region-specific and getting it wrong
    points Terraform at the wrong tenant.

      EU (app.port.io) -> https://api.port.io
      US (app.us.port.io) -> https://api.us.port.io

    CONFIRMED 2026-08-18 (G-3): the credentials in use authenticate
    against EU. The US endpoint returns 401 for them. Verified by
    calling /v1/auth/access_token against both hosts, not assumed.
    If Mayo later procures a US tenant this default changes in the
    same PR as the credentials, never separately.

    The legacy *.getport.io hostnames still resolve but the *.port.io
    form is the documented one. Phase 0 open item "Confirm US Port
    instance" decides this value; it also decides the data-residency
    story, so do not guess it.
  EOT
  type        = string
  default     = "https://api.port.io"

  validation {
    condition     = can(regex("^https://api\\.(us\\.)?(get)?port\\.io$", var.port_base_url))
    error_message = "port_base_url must be https://api.port.io or https://api.us.port.io (or the legacy getport.io equivalents)."
  }
}

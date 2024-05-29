variable "workload_identity" {
  type = object({
    enabled    = bool
    project_id = optional(string)
  })
  default = {
    enabled = false
  }
  validation {
    condition = (
      (var.workload_identity.enabled && var.workload_identity.project_id != null)
      || (!var.workload_identity.enabled)
    )
    error_message = "A project_id must be specified if workload_identity_enabled is set."
  }
}

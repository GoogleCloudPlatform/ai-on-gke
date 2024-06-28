/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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

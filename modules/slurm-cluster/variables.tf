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

variable "namespace" {
  description = "Namespace used for Slurm cluster resources."
  type        = string
  nullable    = false
  default     = "default"
}

variable "namespace_create" {
  description = "Create namespace use for Slurm cluster resources."
  type        = bool
  nullable    = false
  default     = false
}

variable "cluster_config" {
  description = "Configure Slurm cluster statefulset parameters."
  type = object({
    name  = optional(string, "linux")
    image = optional(string, "")
    database = object({
      create          = optional(bool, true)
      host            = optional(string, "mysql")
      user            = optional(string, "slurm")
      password        = optional(string, "")
      storage_size_gb = optional(number, 1)
    })
    munge = object({
      key = optional(string, "")
    })
    storage = optional(object({
      mount_path = optional(string, "/home")
      type       = optional(string, "filestore")
      size_gb    = optional(number, 100)
    }))
  })
  nullable = false
}

variable "templates_path" {
  description = "Path where manifest templates will be read from. Set to null to use the default manifests"
  type        = string
  default     = null
}

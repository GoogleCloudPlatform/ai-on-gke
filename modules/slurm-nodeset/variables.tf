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

variable "name" {
  description = "Name used for Slurm worker nodes configuration"
  type        = string
  nullable    = false
}

variable "templates_path" {
  description = "Path where manifest templates will be read from. Set to null to use the default manifests."
  type        = string
  default     = null
}

variable "config" {
  type = object({
    type      = string # Machine Type
    instances = number # Number of Slurm instances
    namespace = string # Cluster namespace
    image     = string #"Container image used for Slurm cluster pods"
    accelerator = optional(object({
      type  = string # "Needed when the configured instances is an N1-standard-* since GPUs are not known in advanced."
      count = number
    }))
    storage = optional(object({
      mount_path = optional(string, "/home")
      type       = optional(string, "filestore")
    }))
  })
  default = null
}

variable "accelerator_types" {
  type = map(object({
    type   = optional(string)
    count  = optional(number)
    cpu    = optional(number)
    memory = optional(number)
  }))

  default = {
    "g2-standard-4" = {
      type  = "nvidia-l4"
      count = 1
    }
    "g2-standard-8" = {
      type  = "nvidia-l4"
      count = 1
    }
    "g2-standard-12" = {
      type  = "nvidia-l4"
      count = 1
    }
    "g2-standard-16" = {
      type  = "nvidia-l4"
      count = 1
    }
    "g2-standard-24" = {
      type  = "nvidia-l4"
      count = 2
    }
    "g2-standard-32" = {
      type  = "nvidia-l4"
      count = 1
    }
    "g2-standard-48" = {
      type  = "nvidia-l4"
      count = 4
    }
    "g2-standard-96" = {
      type  = "nvidia-l4"
      count = 8
    }
  }
}


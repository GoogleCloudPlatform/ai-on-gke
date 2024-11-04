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


variable "cluster_name" {
  description = "Cluster Name to use"
  type        = string
  nullable    = false
}

variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
  nullable    = false
}

variable "region" {
  description = "Google Cloud Region where the GKE cluster is located"
  type        = string
  nullable    = false
}

variable "impersonate_service_account" {
  description = "Service account to be used while using Google Cloud APIs"
  type        = string
  nullable    = true
  default     = null
}

variable "config" {
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
    storage = object({
      type    = optional(string, "filestore")
      size_gb = optional(number, 100)
    })
  })
  nullable = false
}

variable "credentials_config" {
  description = "Configure how Terraform authenticates to the cluster."
  type = object({
    fleet_host = optional(string)
    kubeconfig = optional(object({
      context = optional(string)
      path    = optional(string, "~/.kube/config")
    }))
  })
  nullable = false
  validation {
    condition = (
      (var.credentials_config.fleet_host != null) !=
      (var.credentials_config.kubeconfig != null)
    )
    error_message = "Exactly one of fleet host or kubeconfig must be set."
  }
  default = {
    kubeconfig = {
      path = "~/.kube/config"
    }
  }
}

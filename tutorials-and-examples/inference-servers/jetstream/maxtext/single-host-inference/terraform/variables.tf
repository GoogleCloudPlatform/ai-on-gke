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


variable "credentials_config" {
  description = "Configure how Terraform authenticates to the cluster."
  type = object({
    fleet_host = optional(string)
    kubeconfig = optional(object({
      context = optional(string)
      path    = optional(string, "~/.kube/config")
    }))
  })
  nullable = true
  default = {
    kubeconfig = {
      path : "~/.kube/config"
    }
  }
  validation {
    condition = (
      (var.credentials_config.fleet_host != null) !=
      (var.credentials_config.kubeconfig != null)
    )
    error_message = "Exactly one of fleet host or kubeconfig must be set."
  }
}

variable "namespace" {
  description = "Namespace used for Jetstream resources."
  type        = string
  nullable    = false
  default     = "default"
}

variable "maxengine_server_image" {
  description = "maxengine-server container image"
  type        = string
  default     = "us-docker.pkg.dev/cloud-tpu-images/inference/maxengine-server:v0.2.2"
  nullable    = false
}

variable "jetstream_http_server_image" {
  description = "jetstream-http container image"
  type        = string
  default     = "us-docker.pkg.dev/cloud-tpu-images/inference/jetstream-http:v0.2.2"
  nullable    = false
}


variable "bucket_name" {
  description = "Name of Google Cloud Storage bucket hosting unscanned checkpoints"
  type        = string
  nullable    = false
}

variable "templates_path" {
  description = "Path where manifest templates will be read from. Set to null to use the default manifests"
  type        = string
  default     = null
}

variable "hpa_type" {
  description = "How the Jetstream workload should be scaled."
  type        = string
  default     = null
  nullable    = true
  validation {
    condition     = var.hpa_type == null ? true : length(regexall("jetstream_.*", var.hpa_type)) > 0 || length(regexall("memory_used", var.hpa_type)) > 0
    error_message = "Allows values for hpa_type are {null, memory_used, jetstream metrics (e.g., \"jetstream_prefill_backlog_size\", \"jetstream_slots_used_percentage\")}"
  }
}

variable "hpa_min_replicas" {
  description = "Minimum number of HPA replicas."
  type        = number
  default     = 1
  nullable    = false
}

variable "hpa_max_replicas" {
  description = "Maximum number of HPA replicas."
  type        = number
  default     = 5
  nullable    = false
}

# TODO: combine hpa variables into a single object (so that they can be
# validated together)
variable "hpa_averagevalue_target" {
  description = "AverageValue target for the `hpa_type` metric. Must be set if `hpa_type` is not null."
  type        = number
  default     = null
  nullable    = true
}

variable "project_id" {
  description = "Project id of existing or created project."
  type        = string
  nullable    = false
}

variable "custom_metrics_enabled" {
  description = "Enable custom metrics collection"
  type        = bool
  default     = false
  nullable    = false
}

variable "metrics_port" {
  description = "Port to scrape metrics from"
  type        = number
  nullable    = true
}
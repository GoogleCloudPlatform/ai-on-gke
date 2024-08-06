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

variable "project_id" {
  description = "Project id of existing or created project."
  type        = string
  nullable    = false
}

variable "cluster_name" {
  type = string
}

variable "maxengine_deployment_settings" {
  type = object({
    maxengine_server_image      = optional(string)
    jetstream_http_server_image = optional(string)

    model_name      = string // Name of your LLM (for example: "gemma-7b")
    parameters_path = string // Path to the parameters for your model

    metrics = optional(object({  // Settings for metrics server
      server = optional(object({ // Settings for Jetstream server metrics
        port            = number
        scrape_interval = number
      }))
      system = optional(object({ // Settings for TPU metrics
        scrape_interval = number
      }))
    }))

    accelerator_selectors = object({
      topology    = string
      accelerator = string
      chip_count  = number
    })
  })
}

variable "hpa_config" {
  type = object({
    metrics_adapter = string
    min_replicas    = number
    max_replicas    = number
    rules = list(object({
      target_query         = string
      average_value_target = number
    }))
  })
  default = null

  validation {
    condition = alltrue([
      for hpa_config in var.hpa_config.rules :
      hpa_config.target_query != null && hpa_config.average_value_target != null && length(regexall("jetstream_.*", hpa_config.target_query)) > 0 || length(regexall("memory_used", hpa_config.target_query)) > 0 || length(regexall("memory_used_percentage", hpa_config.target_query)) > 0
    ])
    error_message = "Allows values for hpa_type are {null, memory_used, predefined promql queries (i.e. memory_used_percentage, or jetstream metrics (e.g., \"jetstream_prefill_backlog_size\", \"jetstream_slots_used_percentage\")}"
  }
  validation {
    condition = var.hpa_config.metrics_adapter == "custom-metrics-stackdriver-adapter" && alltrue([
      for hpa_config in var.hpa_config.rules :
      hpa_config.target_query != null && hpa_config.average_value_target != null && length(regexall("jetstream_.*", hpa_config.target_query)) > 0 || length(regexall("memory_used", hpa_config.target_query)) > 0
    ]) || var.hpa_config.metrics_adapter != "custom-metrics-stackdriver-adapter"
    error_message = "Allowed values for target_query when using the custom-metrics-stackdriver are \"memory_used\", or jetstream metrics (i.e. \"jetstream_prefill_backlog_size\", \"jetstream_slots_used_percentage\", etc)"
  }
  validation {
    condition = var.hpa_config.metrics_adapter == "prometheus-adapter" && alltrue([
      for hpa_config in var.hpa_config.rules :
      hpa_config.target_query != null && hpa_config.average_value_target != null && length(regexall("jetstream_.*", hpa_config.target_query)) > 0 || length(regexall("memory_used_percentage", hpa_config.target_query)) > 0
    ]) || var.hpa_config.metrics_adapter != "prometheus-adapter"
    error_message = "Allowed values for target_query when using the prometheus adapter include predefined promql queries (i.e. \"memory_used_percentage\") and jetstream metrics (i.e. \"jetstream_prefill_backlog_size\", \"jetstream_slots_used_percentage\", etc)"
  }
  validation {
    condition     = contains(["", "custom-metrics-stackdriver-adapter", "prometheus-adapter"], var.hpa_config.metrics_adapter)
    error_message = "Allowed values for metrics_adapter are \"custom-metrics-stackdriver-adapter\", or \"prometheus-adapter\"."
  }
}
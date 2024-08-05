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
  type     = string
  nullable = false
}

variable "project_id" {
  type     = string
  nullable = false
}

variable "maxengine_deployment_settings" {
  type = object({
    maxengine_server_image      = optional(string, "us-docker.pkg.dev/cloud-tpu-images/inference/maxengine-server:v0.2.2")
    jetstream_http_server_image = optional(string, "us-docker.pkg.dev/cloud-tpu-images/inference/jetstream-http:v0.2.2")

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

  validation {
    condition     = contains(["gemma-7b", "llama2-7b", "llama2-13b"], var.maxengine_deployment_settings.model_name)
    error_message = "model_name must be one of \"gemma-7b\", \"llama2-7b\", or \"llama2-13b\""
  }

  validation {
    condition     = try(var.maxengine_deployment_settings.metrics.server.scrape_interval >= 5, true)
    error_message = "Server metrics scrape interval may not be shorter than 5s"
  }

  validation {
    condition     = try(var.maxengine_deployment_settings.metrics.system.scrape_interval >= 15, true)
    error_message = "TPU system metrics scrape interval may not be shorter than 15s"
  }
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
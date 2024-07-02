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

variable "bucket_name" {
  description = "Name of Google Cloud Storage bucket hosting unscanned checkpoints"
  type        = string
  nullable    = false
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

variable "custom_metrics_enabled" {
  description = "Enable custom metrics collection"
  type        = bool
  default     = false
  nullable    = false
}

variable "metrics_port" {
  description = "Port to emit metrics from, set to null to disable metrics"
  type        = number
  default     = 9100
  nullable    = true
}

variable "metrics_adapter" {
  description = "Adapter to use for exposing GKE metrics to cluster"
  type        = string
  nullable    = true
  default     = null

  validation {
    condition     = contains(["", "custom-metrics-stackdriver-adapter", "prometheus-adapter"], var.metrics_adapter)
    error_message = "Allowed values for metrics_adapter are \"custom-metrics-stackdriver-adapter\", or \"prometheus-adapter\"."
  }
}

variable "hpa_type" {
  description = "How the Jetstream workload should be scaled."
  type        = string
  default     = null
  nullable    = true
  validation {
    condition     = var.hpa_type == null ? true : length(regexall("jetstream_.*", var.hpa_type)) > 0 || length(regexall("memory_used", var.hpa_type)) > 0 || length(regexall("accelerator_memory_used_percentage", var.hpa_type)) > 0
    error_message = "Allows values for hpa_type are {null, memory_used, predefined promql queries (i.e. accelerator_memory_used_percentage, or jetstream metrics (e.g., \"jetstream_prefill_backlog_size\", \"jetstream_slots_used_percentage\")}"
  }
}

variable "hpa_configs" {
  type = object({
    min_replicas = number
    max_replicas = number
    rules = list(object({
      target_query = string
      average_value_target = number
    }))
  })
  default = null

  validation {
    condition = alltrue([
      for hpa_config in var.hpa_configs.rules : 
        hpa_config.target_query == null ? true : length(regexall("jetstream_.*", hpa_config.target_query)) > 0 || length(regexall("memory_used", hpa_config.target_query)) > 0 || length(regexall("accelerator_memory_used_percentage", hpa_config.target_query)) > 0
    ])
    
    error_message = "Allows values for hpa_type are {null, memory_used, predefined promql queries (i.e. accelerator_memory_used_percentage, or jetstream metrics (e.g., \"jetstream_prefill_backlog_size\", \"jetstream_slots_used_percentage\")}"
  }
}
# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "project_id" {
  type        = string
  description = "GCP project id"
  default     = "umeshkumhar"
}

variable "region" {
  type        = string
  description = "GCP project region or zone"
  default     = "us-central1"
}

## network variables
variable "network_name" {
  type = string
}

variable "subnetwork_name" {
  type = string
}

## GKE variables
variable "cluster_regional" {
  type = bool
}

variable "cluster_name" {
  type = string
}

variable "cluster_labels" {
  type        = map
  description = "GKE cluster labels"
}

variable "kubernetes_version" {
  type = string
}

variable "cluster_region" {
  type = string
}

variable "cluster_zones" {
  type = list(string)
}
variable "ip_range_pods" {
  type = string
}
variable "ip_range_services" {
  type = string
}
variable "monitoring_enable_managed_prometheus" {
  type    = bool
  default = false
}
variable "all_node_pools_oauth_scopes" {
  type = list(string)
}
variable "all_node_pools_labels" {
  type = map(string)
}
variable "all_node_pools_metadata" {
  type = map(string)
}
variable "all_node_pools_tags" {
  type = list(string)
}

variable "master_authorized_networks" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "enable_tpu" {
  type        = bool
  description = "Set to true to create TPU node pool"
  default     = false
}
variable "enable_gpu" {
  type        = bool
  description = "Set to true to create TPU node pool"
  default     = true
}

variable "cpu_pools" {
  type = list(map(any))
}

variable "gpu_pools" {
  type = list(map(any))
}

variable "tpu_pools" {
  type = list(map(any))
}
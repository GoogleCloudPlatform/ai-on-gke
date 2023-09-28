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
variable "create_network" {
  type = bool
}

variable "network_name" {
  type = string
}

variable "subnetwork_name" {
  type = string
}

variable "subnetwork_cidr" {
  type = string
}

variable "subnetwork_region" {
  type = string
}

variable "subnetwork_private_access" {
  type = string
}

variable "subnetwork_description" {
  type = string
}

variable "network_secondary_ranges" {
  type = map(list(object({ range_name = string, ip_cidr_range = string })))
}

## GKE variables
variable "create_cluster" {
  type = bool
}

variable "cluster_name" {
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
  type = list(object({
    name                   = optional(string)
    machine_type           = optional(string)
    node_locations         = optional(string)
    autoscaling            = optional(bool)
    min_count              = optional(number)
    max_count              = optional(number)
    local_ssd_count        = optional(number)
    spot                   = optional(bool)
    disk_size_gb           = optional(number)
    disk_type              = optional(string)
    image_type             = optional(string)
    enable_gcfs            = optional(bool)
    enable_gvnic           = optional(bool)
    logging_variant        = optional(string)
    auto_repair            = optional(bool)
    auto_upgrade           = optional(bool)
    create_service_account = optional(bool)
    preemptible            = optional(bool)
    initial_node_count     = optional(number)
    accelerator_count      = optional(number)
    accelerator_type       = optional(string)
  }))
}

variable "gpu_pools" {
  type = list(object({
    name                   = optional(string)
    machine_type           = optional(string)
    node_locations         = optional(string)
    autoscaling            = optional(bool)
    min_count              = optional(number)
    max_count              = optional(number)
    local_ssd_count        = optional(number)
    spot                   = optional(bool)
    disk_size_gb           = optional(number)
    disk_type              = optional(string)
    image_type             = optional(string)
    enable_gcfs            = optional(bool)
    enable_gvnic           = optional(bool)
    logging_variant        = optional(string)
    auto_repair            = optional(bool)
    auto_upgrade           = optional(bool)
    create_service_account = optional(bool)
    preemptible            = optional(bool)
    initial_node_count     = optional(number)
    accelerator_count      = optional(number)
    accelerator_type       = optional(string)
  }))
}

variable "tpu_pools" {
  type = list(object({
    name                   = optional(string)
    machine_type           = optional(string)
    node_locations         = optional(string)
    autoscaling            = optional(bool)
    min_count              = optional(number)
    max_count              = optional(number)
    local_ssd_count        = optional(number)
    spot                   = optional(bool)
    disk_size_gb           = optional(number)
    disk_type              = optional(string)
    image_type             = optional(string)
    enable_gcfs            = optional(bool)
    enable_gvnic           = optional(bool)
    logging_variant        = optional(string)
    auto_repair            = optional(bool)
    auto_upgrade           = optional(bool)
    create_service_account = optional(bool)
    preemptible            = optional(bool)
    initial_node_count     = optional(number)
    accelerator_count      = optional(number)
    accelerator_type       = optional(string)
  }))
}

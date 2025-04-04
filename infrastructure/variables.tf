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
  type    = string
  default = "10.128.0.0/20"
}

variable "subnetwork_region" {
  type    = string
  default = "us-central1"
}

variable "subnetwork_private_access" {
  type    = string
  default = "true"
}

variable "subnetwork_description" {
  type    = string
  default = ""
}

variable "network_secondary_ranges" {
  type    = map(list(object({ range_name = string, ip_cidr_range = string })))
  default = {}
}

## GKE variables
variable "create_cluster" {
  type    = bool
  default = true
}

variable "private_cluster" {
  type    = bool
  default = true
}

variable "autopilot_cluster" {
  type = bool
}

variable "cluster_regional" {
  type    = bool
  default = true
}

variable "cluster_name" {
  type = string
}

variable "cluster_labels" {
  type        = map(any)
  description = "GKE cluster labels"
  default = {
    "created-by" = "ai-on-gke"
  }
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "release_channel" {
  type    = string
  default = "REGULAR"
}

variable "cluster_location" {
  type = string
}

variable "ip_range_pods" {
  type    = string
  default = ""
}
variable "ip_range_services" {
  type    = string
  default = ""
}
variable "monitoring_enable_managed_prometheus" {
  type    = bool
  default = true
}
variable "gcs_fuse_csi_driver" {
  type    = bool
  default = true
}
variable "deletion_protection" {
  type    = bool
  default = false
}

variable "ray_addon_enabled" {
  type        = bool
  description = "Set to true to enable ray addon"
  default     = true
}

variable "master_authorized_networks" {
  type = list(object({
    cidr_block   = string
    display_name = optional(string)
  }))
  default = []
}

variable "master_ipv4_cidr_block" {
  type    = string
  default = ""
}

variable "all_node_pools_oauth_scopes" {
  type = list(string)
  default = [
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/trace.append",
    "https://www.googleapis.com/auth/service.management.readonly",
    "https://www.googleapis.com/auth/servicecontrol",
  ]
}
variable "all_node_pools_labels" {
  type = map(string)
  default = {
    "created-by" = "ai-on-gke"
  }
}
variable "all_node_pools_metadata" {
  type = map(string)
  default = {
    disable-legacy-endpoints = "true"
  }
}
variable "all_node_pools_tags" {
  type    = list(string)
  default = ["gke-node", "ai-on-gke"]
}

variable "enable_tpu" {
  type        = bool
  description = "Set to true to create TPU node pool"
  default     = false
}

variable "enable_gpu" {
  type        = bool
  description = "Set to true to create GPU node pool"
  default     = true
}

variable "cpu_pools" {
  type = list(object({
    name                   = string
    machine_type           = string
    node_locations         = optional(string, "")
    autoscaling            = optional(bool, false)
    min_count              = optional(number, 1)
    max_count              = optional(number, 3)
    local_ssd_count        = optional(number, 0)
    spot                   = optional(bool, false)
    disk_size_gb           = optional(number, 100)
    disk_type              = optional(string, "pd-standard")
    image_type             = optional(string, "COS_CONTAINERD")
    enable_gcfs            = optional(bool, false)
    enable_gvnic           = optional(bool, false)
    logging_variant        = optional(string, "DEFAULT")
    auto_repair            = optional(bool, true)
    auto_upgrade           = optional(bool, true)
    create_service_account = optional(bool, true)
    preemptible            = optional(bool, false)
    initial_node_count     = optional(number, 1)
    accelerator_count      = optional(number, 0)
    queued_provisioning    = optional(bool, false)
  }))
  default = [{
    name         = "cpu-pool"
    machine_type = "n1-standard-16"
    autoscaling  = true
    min_count    = 1
    max_count    = 3
    disk_size_gb = 100
    disk_type    = "pd-standard"
  }]
}

variable "gpu_pools" {
  type = list(object({
    name                   = string
    machine_type           = string
    node_locations         = optional(string, "")
    autoscaling            = optional(bool, false)
    min_count              = optional(number, 1)
    max_count              = optional(number, 3)
    local_ssd_count        = optional(number, 0)
    spot                   = optional(bool, false)
    disk_size_gb           = optional(number, 100)
    disk_type              = optional(string, "pd-standard")
    image_type             = optional(string, "COS_CONTAINERD")
    enable_gcfs            = optional(bool, false)
    enable_gvnic           = optional(bool, false)
    logging_variant        = optional(string, "DEFAULT")
    auto_repair            = optional(bool, true)
    auto_upgrade           = optional(bool, true)
    create_service_account = optional(bool, true)
    preemptible            = optional(bool, false)
    initial_node_count     = optional(number, 1)
    accelerator_count      = optional(number, 0)
    accelerator_type       = optional(string, "nvidia-tesla-t4")
    gpu_driver_version     = optional(string, "DEFAULT")
    queued_provisioning    = optional(bool, false)
  }))
  default = [{
    name               = "gpu-pool"
    machine_type       = "n1-standard-16"
    autoscaling        = true
    min_count          = 1
    max_count          = 3
    disk_size_gb       = 100
    disk_type          = "pd-standard"
    accelerator_count  = 2
    accelerator_type   = "nvidia-tesla-t4"
    gpu_driver_version = "DEFAULT"
  }]
}

variable "tpu_pools" {
  type = list(object({
    name                   = string
    machine_type           = string
    node_locations         = string
    autoscaling            = optional(bool, false)
    min_count              = optional(number, 1)
    max_count              = optional(number, 3)
    local_ssd_count        = optional(number, 0)
    spot                   = optional(bool, false)
    disk_size_gb           = optional(number, 100)
    disk_type              = optional(string, "pd-standard")
    image_type             = optional(string, "COS_CONTAINERD")
    enable_gcfs            = optional(bool, false)
    enable_gvnic           = optional(bool, false)
    logging_variant        = optional(string, "DEFAULT")
    auto_repair            = optional(bool, true)
    auto_upgrade           = optional(bool, true)
    create_service_account = optional(bool, true)
    preemptible            = optional(bool, false)
    initial_node_count     = optional(number, 1)
    accelerator_count      = optional(number, 0)
    accelerator_type       = optional(string, "nvidia-tesla-t4")
    queued_provisioning    = optional(bool, false)
  }))
  default = []
}

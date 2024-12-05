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

variable "gke_autopilot" {
  description = "Create GKE Autopiot cluster"
  type        = bool
  default     = false
}

variable "cluster_create" {
  description = "Cluster configuration for newly created cluster. Set to null to use existing cluster, or create using defaults in new project."
  type = object({
    labels = optional(map(string))
    master_authorized_ranges = optional(map(string), {
      rfc-1918-10-8 = "10.0.0.0/8"
    })
    master_ipv4_cidr_block = optional(string, "172.16.255.0/28")
    vpc = optional(object({
      id        = string
      subnet_id = string
      secondary_range_names = optional(object({
        pods     = optional(string, "pods")
        services = optional(string, "services")
      }), {})
    }))
    version = optional(string)
    options = optional(object({
      release_channel                       = optional(string, "REGULAR")
      enable_backup_agent                   = optional(bool, false)
      dns_cache                             = optional(bool, true)
      enable_gcs_fuse_csi_driver            = optional(bool, false)
      enable_gcp_filestore_csi_driver       = optional(bool, false)
      enable_gce_persistent_disk_csi_driver = optional(bool, false)
    }), {})
  })
  default = null
}

variable "project_create" {
  description = "Project configuration for newly created project. Leave null to use existing project. Project creation forces VPC and cluster creation."
  type = object({
    billing_account = string
    parent          = optional(string)
    shared_vpc_host = optional(string)
  })
  default = null
}

variable "registry_create" {
  description = "Create remote Docker Artifact Registry."
  type        = bool
  default     = true
}

variable "vpc_create" {
  description = "Project configuration for newly created VPC. Leave null to use existing VPC, or defaults when project creation is required."
  type = object({
    name                     = optional(string)
    subnet_name              = optional(string)
    primary_range_nodes      = optional(string, "10.0.0.0/24")
    secondary_range_pods     = optional(string, "10.16.0.0/20")
    secondary_range_services = optional(string, "10.32.0.0/24")
    enable_cloud_nat         = optional(bool, false)
    proxy_only_subnet        = optional(string)
  })
  default = null
}

variable "enable_private_endpoint" {
  description = "When true, the cluster's private endpoint is used as the cluster endpoint and access through the public endpoint is disabled. Ignored if private_cluster_config set to null. May need to destroy & recreate to apply public cluster."
  type        = bool
  default     = true
}

variable "private_cluster_config" {
  description = "Private cluster configuration. Default of {} configures a private_cluster with the values in below object. Set to null to make cluster public, which can be used for simple kubectl access when debugging or learning but should not be used in production."
  type = object({
    master_global_access = optional(bool, true)
  })
  default = {}
}

variable "cluster_name" {
  description = "Name of new or existing cluster."
  type        = string
}

# https://cloud.google.com/anthos/fleet-management/docs/before-you-begin/gke#gke-cross-project

variable "fleet_project_id" {
  description = "GKE Fleet project id. If null cluster project will also be used for fleet."
  type        = string
  default     = null
}

variable "prefix" {
  description = "Prefix used for resource names."
  type        = string
  nullable    = false
  default     = "ai-gke-0"
}

variable "project_id" {
  description = "Project id of existing or created project."
  type        = string
}

variable "region" {
  description = "Region used for network resources."
  type        = string
  default     = "us-central1"
}

variable "gke_location" {
  description = "Region or zone used for cluster."
  type        = string
  default     = "us-central1-a"
}

variable "node_locations" {
  description = "Zones in which the GKE Autopilot cluster's nodes are located."
  type        = list(string)
  default     = []
}

variable "nodepools" {
  description = "Nodepools for the GKE Standard cluster"
  type = map(object({
    machine_type   = optional(string, "n2-standard-2"),
    gke_version    = optional(string),
    max_node_count = optional(number, 10),
    min_node_count = optional(number, 1),
    spot           = optional(bool, false)

    guest_accelerator = optional(object({
      type  = optional(string),
      count = optional(number),
      gpu_driver = optional(object({
        version                    = string
        partition_size             = optional(string)
        max_shared_clients_per_gpu = optional(number)
      }))
    }))

    ephemeral_ssd_block_config = optional(object({
      ephemeral_ssd_count = optional(number)
    }))

    local_nvme_ssd_block_config = optional(object({
      local_ssd_count = optional(number)
    }))
  }))
  default = {}
}

variable "filestore_storage" {
  description = "Filestore storage instances. If GKE deployment is regional, tier should be set to ENTERPRISE"
  type = map(object({
    name        = string
    tier        = string
    capacity_gb = number
  }))
  default = {}
}


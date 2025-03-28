# # Copyright 2023 Google LLC
# #
# # Licensed under the Apache License, Version 2.0 (the "License");
# # you may not use this file except in compliance with the License.
# # You may obtain a copy of the License at
# #
# #     http://www.apache.org/licenses/LICENSE-2.0
# #
# # Unless required by applicable law or agreed to in writing, software
# # distributed under the License is distributed on an "AS IS" BASIS,
# # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# # See the License for the specific language governing permissions and
# # limitations under the License.

variable "project_id" {
  type        = string
  description = "GCP project id"
}

## Flyte variables
variable "kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace where Flyte resources are deployed"
  default     = "default"
}

variable "helm_release_name" {
  type        = string
  description = "The name of the helm release for Flyte"
  default     = "flyte-backend"
}

variable "flyte_projects" {
  type        = list(string)
  description = "List of Flyte projects"
  default     = ["flytesnacks"]
}

## GKE Cluster variables
variable "cluster_name" {
  type = string
  description = "Name of the GKE cluster to be created"
}

variable "cluster_location" {
  type = string
  description = "Location of the GKE cluster"
}


variable "create_cluster" {
  type    = bool
  default = false
}

variable "private_cluster" {
  type    = bool
  default = false
}

variable "autopilot_cluster" {
  type    = bool
  default = true
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
  }))
  default = [{
    name         = "cpu-pool"
    machine_type = "n1-standard-16"
    autoscaling  = true
    min_count    = 1
    max_count    = 3
    enable_gcfs  = true
    disk_size_gb = 100
    disk_type    = "pd-standard"
  }]
}

variable "enable_gpu" {
  type    = bool
  description = "Enable GPU support in the GKE cluster by adding GPU pools"
  default = false
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
    name               = "gpu-pool-l4"
    machine_type       = "g2-standard-24"
    autoscaling        = true
    min_count          = 0
    max_count          = 3
    disk_size_gb       = 100
    disk_type          = "pd-balanced"
    enable_gcfs        = true
    accelerator_count  = 2
    accelerator_type   = "nvidia-l4"
    gpu_driver_version = "DEFAULT"
  }]
}

variable "kubernetes_version" {
  type        = string
  description = "Set Kubernetes version"
  default     = "1.30"
}

## Network variables
variable "create_network" {
  type        = bool
  description = "Whether to create a network (otherwise, use an existing one)"
  default     = false
}

variable "network_name" {
  type        = string
  description = "Name of the network where resources are deployed"
}

variable "subnetwork_name" {
  type        = string
  description = "Name of the subnetwork where cluster is deployed"
}

## GCS variables
variable "create_gcs_bucket" {
  type        = bool
  description = "Whether to create a GCS bucket"
  default     = false
}

variable "gcs_bucket" {
  type        = string
  description = "Name for the created GCS bucket"
}

## Database variables
variable "db_tier" {
  type        = string
  description = "Tier for the database instance"
  default     = "db-f1-micro"
}

variable "cloudsql_user" {
  type        = string
  description = "Username for the cloudsql database"
  default     = "flytepg"
}

variable "database_name" {
  type        = string
  description = "Name of the database"
  default     = "flytepg"
}

variable "db_instance_name" {
  type        = string
  description = "Name of the database instance"
  default     = "flytepg"
}

## Helm chart variables
variable "render_helm_values" {
  type        = bool
  description = "Render values.yaml for helm chart"
  default     = true
}

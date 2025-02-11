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

variable "cluster_name" {
  type = string
}

variable "cluster_location" {
  type = string
}

variable "cluster_membership_id" {
  type        = string
  description = "require to use connectgateway for private clusters, default: cluster_name"
  default     = ""
}

variable "kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace where resources are deployed"
  default     = "ai-on-gke"
}
variable "create_service_account" {
  type        = bool
  description = "Creates a google IAM service account & k8s service account & configures workload identity"
  default     = true
}

variable "workload_identity_service_account" {
  type        = string
  description = "Google Cloud IAM service account for authenticating with GCP services for GCS"
  default     = "sky-sa"
}

variable "enable_gpu" {
  type    = bool
  default = false
}

variable "enable_tpu" {
  type    = bool
  default = false
}

## GKE variables
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

variable "goog_cm_deployment_name" {
  type    = string
  default = ""
}

# Ray-dashboard IAP settings
variable "create_brand" {
  type        = bool
  description = "Create Brand OAuth Screen"
  default     = false
}

variable "additional_labels" {
  // string is used instead of map(string) since blueprint metadata does not support maps.
  type        = string
  description = "Additional labels to add to Kubernetes resources."
  default     = "created-by=ai-on-gke,ai.gke.io=ray"
}

variable "kubernetes_version" {
  type        = string
  description = "Set Kubernetes version"
  default     = "1.30"
}

variable "create_gcs_bucket" {
  type        = bool
  description = "Wether to create a GCS bucket"
  default     = false
}

variable "gcs_bucket" {
  type        = string
  description = "Name for the created GCS bucket"
}

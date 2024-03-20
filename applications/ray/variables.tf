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

variable "ray_version" {
  type    = string
  default = "v2.9.3"
}

variable "kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace where resources are deployed"
  default     = "myray"
}

variable "enable_grafana_on_ray_dashboard" {
  type        = bool
  description = "Add option to enable or disable grafana for the ray dashboard. Enabling requires anonymous access."
  default     = false
}

variable "create_gcs_bucket" {
  type        = bool
  default     = false
  description = "Enable flag to create gcs_bucket"
}

variable "gcs_bucket" {
  type = string
}

variable "create_service_account" {
  type        = bool
  description = "Creates a google IAM service account & k8s service account & configures workload identity"
  default     = true
}

variable "workload_identity_service_account" {
  type        = string
  description = "Google Cloud IAM service account for authenticating with GCP services for GCS"
  default     = "ray-service-account"
}

variable "create_ray_cluster" {
  type    = bool
  default = false
}

variable "ray_cluster_name" {
  type    = string
  default = "example-cluster"
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
  default = false
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

variable "goog_cm_deployment_name" {
  type    = string
  default = ""
}

# Defaulted to enforced baseline Pod Security Standards with restricted
# in audit and warn mode.
variable "namespace_labels" {
  type        = map(any)
  description = "Labels to apply to the Ray cluster namespace"
  default = {
    "pod-security.kubernetes.io/audit" : "restricted"
    "pod-security.kubernetes.io/audit-version" : "latest"
    "pod-security.kubernetes.io/enforce" : "baseline"
    "pod-security.kubernetes.io/enforce-version" : "latest"
    "pod-security.kubernetes.io/warn" : "restricted"
    "pod-security.kubernetes.io/warn-version" : "latest"
  }
}

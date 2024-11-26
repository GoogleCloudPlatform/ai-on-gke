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
}

variable "additional_labels" {
  // string is used instead of map(string) since blueprint metadata does not support maps.
  type        = string
  description = "Additional labels to add to Kubernetes resources."
  default     = "created-by=ai-on-gke,ai.gke.io=jupyter"
}

variable "gcs_bucket" {
  type        = string
  description = "Bucket name to store the dataset"
}

variable "workload_identity_service_account" {
  type        = string
  description = "workload identity service account"
  default     = "jupyter-sa"
}

variable "project_id" {
  type        = string
  description = "GCP project id"
}

variable "members_allowlist" {
  type    = string
  default = ""
  ## keeping it string type to support single field input for marketplace UI.
}

variable "add_auth" {
  type        = bool
  description = "Enable iap authentication on jupyterhub"
  default     = false
}

variable "k8s_ingress_name" {
  type    = string
  default = "jupyter-ingress"
}

variable "k8s_managed_cert_name" {
  type        = string
  description = "Name for frontend managed certificate"
  default     = "jupyter-managed-cert"
}

variable "k8s_iap_secret_name" {
  type    = string
  default = "jupyter-secret"
}

variable "k8s_backend_config_name" {
  type        = string
  description = "Name of the Backend Config on GCP"
  default     = "jupyter-iap-config"
}

variable "k8s_backend_service_name" {
  type        = string
  description = "Name of the Backend Config on GCP, this is defined by Jupyter hub"
  default     = "proxy-public"
}

variable "k8s_backend_service_port" {
  type        = number
  description = "Name of the Backend Service on GCP"
  default     = 80
}

variable "create_brand" {
  type        = bool
  description = "Create Brand OAuth Screen"
  default     = false
}

variable "domain" {
  type        = string
  description = "Provide domain for ingress resource and ssl certificate."
  default     = ""
}

variable "support_email" {
  type        = string
  description = "Email for users to contact with questions about their consent"
  default     = ""
}

variable "client_id" {
  type        = string
  description = "Client ID used for enabling IAP"
  default     = ""
}

variable "client_secret" {
  type        = string
  description = "Client secret used for enabling IAP"
  default     = ""
  sensitive   = false
}

variable "create_gcs_bucket" {
  type        = bool
  default     = false
  description = "Enable flag to create gcs_bucket"
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
    enable_gcfs            = optional(bool, true)
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
  default = []
}

variable "goog_cm_deployment_name" {
  type    = string
  default = ""
}

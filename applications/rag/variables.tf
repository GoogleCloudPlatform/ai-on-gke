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

variable "cluster_membership_id" {
  type        = string
  description = "require to use connectgateway for private clusters, default: cluster_name"
  default     = ""
}

variable "cluster_location" {
  type = string
}

variable "kubernetes_namespace" {
  type        = string
  description = "Kubernetes namespace where resources are deployed"
  default     = "rag"
}

variable "jupyter_service_account" {
  type        = string
  description = "Google Cloud IAM service account for authenticating with GCP services"
  default     = "jupyter"
}

variable "enable_grafana_on_ray_dashboard" {
  type        = bool
  description = "Add option to enable or disable grafana for the ray dashboard. Enabling requires anonymous access."
  default     = false
}
variable "create_ray_service_account" {
  type        = bool
  description = "Creates a google IAM service account & k8s service account & configures workload identity"
  default     = true
}

variable "ray_service_account" {
  type        = string
  description = "Google Cloud IAM service account for authenticating with GCP services"
  default     = "ray-sa"
}

variable "create_rag_service_account" {
  type        = bool
  description = "Creates a google IAM service account & k8s service account & configures workload identity"
  default     = true
}

variable "rag_service_account" {
  type        = string
  description = "Google Cloud IAM service account for authenticating with GCP services"
  default     = "rag-sa"
}

variable "create_gcs_bucket" {
  type        = bool
  default     = false
  description = "Enable flag to create gcs_bucket"
}

variable "gcs_bucket" {
  type        = string
  description = "GCS bucket name to store dataset"
}

variable "dataset_embeddings_table_name" {
  type        = string
  description = "Name of the table that stores vector embeddings for input dataset"
}

variable "brand" {
  type        = string
  description = "name of the brand if there isn't already on the project. If there is already a brand for your project, please leave it blank and empty"
  default     = ""
}

# Frontend IAP settings
variable "frontend_add_auth" {
  type        = bool
  description = "Enable iap authentication on frontend"
  default     = false
}

variable "frontend_k8s_ingress_name" {
  type    = string
  default = "frontend-ingress"
}

variable "frontend_k8s_managed_cert_name" {
  type        = string
  description = "Name for frontend managed certificate"
  default     = "frontend-managed-cert"
}

variable "frontend_k8s_iap_secret_name" {
  type        = string
  description = "Name for frontend iap secret"
  default     = "frontend-iap-secret"
}

variable "frontend_k8s_backend_config_name" {
  type        = string
  description = "Name of the Kubernetes Backend Config"
  default     = "frontend-iap-config"
}

variable "frontend_k8s_backend_service_name" {
  type        = string
  description = "Name of the Backend Service"
  default     = "rag-frontend"
}

variable "frontend_k8s_backend_service_port" {
  type        = number
  description = "Name of the Backend Service Port"
  default     = 8080
}

variable "frontend_url_domain_addr" {
  type        = string
  description = "Domain provided by the user. If it's empty, we will create one for you."
  default     = ""
}

variable "frontend_url_domain_name" {
  type        = string
  description = "Name of the domain provided by the user. This var will only be used if url_domain_addr is not empty"
  default     = ""
}

variable "frontend_support_email" {
  type        = string
  description = "Email for users to contact with questions about their consent"
  default     = ""
}

variable "frontend_client_id" {
  type        = string
  description = "Client ID used for enabling IAP"
  default     = ""
}

variable "frontend_client_secret" {
  type        = string
  description = "Client secret used for enabling IAP"
  default     = ""
}

variable "frontend_members_allowlist" {
  type    = list(string)
  default = []
}

# Jupyter IAP settings
variable "jupyter_add_auth" {
  type        = bool
  description = "Enable iap authentication on jupyterhub"
  default     = false
}

variable "jupyter_k8s_ingress_name" {
  type    = string
  default = "jupyter-ingress"
}

variable "jupyter_k8s_managed_cert_name" {
  type        = string
  description = "Name for frontend managed certificate"
  default     = "jupyter-managed-cert"
}

variable "jupyter_k8s_iap_secret_name" {
  type        = string
  description = "Name for jupyter iap secret"
  default     = "jupyter-iap-secret"
}

variable "jupyter_k8s_backend_config_name" {
  type        = string
  description = "Name of the Kubernetes Backend Config"
  default     = "jupyter-iap-config"
}

variable "jupyter_k8s_backend_service_name" {
  type        = string
  description = "Name of the Backend Service"
  default     = "proxy-public"
}

variable "jupyter_k8s_backend_service_port" {
  type        = number
  description = "Name of the Backend Service Port"
  default     = 80
}

variable "jupyter_url_domain_addr" {
  type        = string
  description = "Domain provided by the user. If it's empty, we will create one for you."
  default     = ""
}

variable "jupyter_url_domain_name" {
  type        = string
  description = "Name of the domain provided by the user. This var will only be used if url_domain_addr is not empty"
  default     = ""
}

variable "jupyter_support_email" {
  type        = string
  description = "Email for users to contact with questions about their consent"
  default     = ""
}

variable "jupyter_client_id" {
  type        = string
  description = "Client ID used for enabling IAP"
  default     = ""
}

variable "jupyter_client_secret" {
  type        = string
  description = "Client secret used for enabling IAP"
  default     = ""
}

variable "jupyter_members_allowlist" {
  type    = list(string)
  default = []
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

variable "cloudsql_instance" {
  type        = string
  description = "Name of the CloudSQL instance for RAG VectorDB"
  default     = "pgvector-instance"
}

variable "cloudsql_instance_region" {
  type        = string
  description = "GCP region for CloudSQL instance"
  default     = ""
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
    },
    {
      name               = "gpu-pool-l4"
      machine_type       = "g2-standard-24"
      autoscaling        = true
      min_count          = 1
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

variable "disable_ray_cluster_network_policy" {
  description = "Disables Kubernetes Network Policy for Ray Clusters for this demo. Defaulting to 'true' aka disabled pending fixes to the kuberay-monitoring module. This should be defaulted to false."
  type        = bool
  default     = true
}

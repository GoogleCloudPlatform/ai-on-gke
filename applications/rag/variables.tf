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
  default     = "jupyter-system-account"
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
  default     = "ray-system-account"
}

variable "create_rag_service_account" {
  type        = bool
  description = "Creates a google IAM service account & k8s service account & configures workload identity"
  default     = true
}

variable "rag_service_account" {
  type        = string
  description = "Google Cloud IAM service account for authenticating with GCP services"
  default     = "rag-system-account"
}

variable "create_gcs_bucket" {
  type = bool
  default = false
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
  default     = true
}

variable "frontend_k8s_ingress_name" {
  type    = string
  default = "frontend-ingress"
}

variable "frontend_k8s_managed_cert_name" {
  type          = string
  description   = "Name for frontend managed certificate"
  default       = "frontend-managed-cert"
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
  default     = true
}

variable "jupyter_k8s_ingress_name" {
  type    = string
  default = "jupyter-ingress"
}

variable "jupyter_k8s_managed_cert_name" {
  type          = string
  description   = "Name for frontend managed certificate"
  default       = "jupyter-managed-cert"
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
  description = "NName of the Backend Service Port"
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
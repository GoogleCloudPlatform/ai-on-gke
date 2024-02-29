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
  description = "GCP project ID"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace where resources are deployed"
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
  default = 8080
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
  type          = string
  description   = "Name for frontend managed certificate"
  default       = "frontend-managed-cert"
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
  default = 80
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
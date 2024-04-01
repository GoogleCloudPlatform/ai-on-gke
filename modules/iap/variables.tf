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

variable "app_name" {
  type        = string
  description = "App Name"
}

# IAP settings
variable "create_brand" {
  type        = bool
  description = "Create Brand OAuth Screen"
}

variable "k8s_ingress_name" {
  type        = string
  description = "Name for k8s Ingress"
}

variable "k8s_managed_cert_name" {
  type        = string
  description = "Name for k8s managed certificate"
}

variable "k8s_iap_secret_name" {
  type        = string
  description = "Name for k8s iap secret"
}

variable "k8s_backend_config_name" {
  type        = string
  description = "Name of the Kubernetes Backend Config"
}

variable "k8s_backend_service_name" {
  type        = string
  description = "Name of the Backend Service"
}

variable "k8s_backend_service_port" {
  type        = number
  description = "Name of the Backend Service Port"
}

variable "domain" {
  type        = string
  description = "Provide domain for ingress resource and ssl certificate. "
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
}

variable "members_allowlist" {
  type    = list(string)
  default = []
}

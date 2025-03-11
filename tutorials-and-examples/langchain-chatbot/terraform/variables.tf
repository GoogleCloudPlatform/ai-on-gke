# Copyright 2024 Google LLC
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

variable "app_name" {
  type        = string
  description = "Name of the application"
  default     = "chat"
}

variable "k8s_namespace" {
  type        = string
  description = "Kubernetes namespace where resources are deployed"
  default     = "default"
}

variable "k8s_app_image" {
  type        = string
  description = "Docker image for the application"
}

variable "k8s_app_deployment_name" {
  type        = string
  description = "Name of the K8s Backend Deployment"
  default     = "chat"
}

variable "k8s_app_service_name" {
  type        = string
  description = "Name of the K8s Backend Service, this is defined by Frontend"
  default     = "chat"
}

variable "k8s_app_service_port" {
  type        = number
  description = "Name of the K8s Backend Service Port"
  default     = 80
}

variable "k8s_ingress_name" {
  type    = string
  default = "chat-ingress"
}

variable "k8s_managed_cert_name" {
  type        = string
  description = "Name for frontend managed certificate"
  default     = "chat-managed-cert"
}

variable "k8s_iap_secret_name" {
  type    = string
  default = "chat-iap-secret"
}

variable "k8s_backend_config_name" {
  type        = string
  description = "Name of the Backend Config on GCP"
  default     = "chat-backend-config"
}

variable "create_brand" {
  type        = bool
  description = "Create Brand OAuth Screen"
  default     = false
}

variable "support_email" {
  type        = string
  description = "Email for users to contact with questions about their consent"
  default     = "<email>"
}

variable "domain" {
  type        = string
  description = "Provide domain for ingress resource and ssl certificate."
  default     = "{IP_ADDRESS}.sslip.io"
}

variable "oauth_client_id" {
  type        = string
  description = "Client ID used for enabling IAP"
}

variable "oauth_client_secret" {
  type        = string
  description = "Client secret used for enabling IAP"
  sensitive   = false
}

variable "members_allowlist" {
  type = list(string)
}

variable "db_instance_name" {
  type        = string
  description = "Name of the Cloud SQL instance"
  default     = "langchain-chatbot"
}

variable "db_name" {
  type        = string
  description = "Name of the database"
  default     = "chat"
}

variable "db_region" {
  type        = string
  description = "Region for the Cloud SQL instance"
  default     = "us-central1"
}

variable "db_tier" {
  type        = string
  description = "Tier for the Cloud SQL instance"
  default     = "db-f1-micro"
}

variable "db_network" {
  type        = string
  description = "VPC network for the Cloud SQL instance to connect to"
}

variable "model_base_url" {
  type        = string
  description = "Base URL for the model"
}

variable "model_name" {
  type        = string
  description = "Name of the model"
}

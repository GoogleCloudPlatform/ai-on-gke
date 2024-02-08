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

variable "namespace" {
  type        = string
  description = "Kubernetes namespace where resources are deployed"
}

variable "default_backend_service" {
  type        = string
  default     = "proxy-public"
}

variable "members_allowlist" {
  type        = string
  default     = ""
}
variable "add_auth" {
  type        = bool
  description = "Enable iap authentication on jupyterhub"
  default     = true
}

variable "gcs_bucket" {
  type = string
  description = "GCS bucket to mount on the notebook via GCSFuse and CSI"
}

variable "k8s_service_account" {
  type = string
  description = "k8s service account"
}

variable "gcp_service_account" {
  type = string
  description = "gcp service account"
}

variable "gcp_service_account_iam_roles" {
  type = string
  description = "Service Account Project IAM binding roles"
}

variable "project_id" {
  type        = string
  description = "GCP project id"
}

variable "service_name" {
  type        = string
  description = "Name of the Backend Service on GCP"
  default     = "iap-config-default"
}

variable "brand" {
  type        = string
  description = "name of the brand if there isn't already on the project. If there is already a brand for your project, please leave it blank and empty"
  default     = ""
}

variable "url_domain_addr" {
  type        = string
  description = "Domain provided by the user. If it's empty, we will create one for you."
  default     = ""
}

variable "url_domain_name" {
  type        = string
  description = "Name of the domain provided by the user. This var will only be used if url_domain_addr is not empty"
  default     = ""
}

variable "support_email" {
  type        = string
  description = "Email for users to contact with questions about their consent"
}

variable "client_id" {
  type        = string
  description = "Client ID used for enabling IAP"
  default     = "" 
}

variable "client_secret" {
  type        = string
  description = "Client secret used for enabling IAP"
  default     =  "" 
  sensitive   = false
}
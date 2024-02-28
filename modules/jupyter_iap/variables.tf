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

variable "client_id" {
  type        = string
  description = "Client ID used for enabling IAP"
  default     = ""
}

variable "client_secret" {
  type        = string
  description = "Client secret used for enabling IAP"
  default     = ""
  sensitive = true
}

variable "iap_client_secret" {
  type        = string
  description = "Name of the IAP secret to be created."
  default     = "iap-client-secret"
}

variable "k8s_ingress_name" {
  type        = string
  description = "Name of the backend service"
  default     = "jupyter-ingress"
}

variable "k8s_backend_service_name" {
  type        = string
  description = "Name of the Backend Service on GCP"
  default = "proxy-public"
}

variable "k8s_backend_config_name" {
  type        = string
  default = "jupyter-iap-config"
  description = "Name of the BackendConfig Service on GCP"
}

variable "members_allowlist" {
  type    = list(string)
  default = []
}

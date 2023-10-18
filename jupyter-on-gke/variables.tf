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
  default     = "<your user name>"
}

variable "create_namespace" {
  type        = bool
  description = "Enable creation of jupyterhub namespace if it does not exist"
  default     = false
}

variable "add_auth" {
  type        = bool
  description = "Enable iap authentication on jupyterhub"
  default     = true
}

variable "project_id" {
  type        = string
  description = "GCP project id"
  default     = "<Project ID here>"
}

variable "location" {
  type        = string
  description = "GCP project location"
  default     = "us-central1"
}

variable "service_name" {
  type        = string
  description = "Name of the Backend Service on GCP"
  default     = "no-id-yet"
}

variable "enable_iap_service" {
  type        = bool
  description = "Flag to enable iap service on this project. If it is already enabled, please set it to false."
  default     = true
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
  default     = "<Support email>"
}
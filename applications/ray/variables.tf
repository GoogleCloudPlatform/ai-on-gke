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
  default = "v2.7.1"
}

variable "ray_namespace" {
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

variable "gcp_service_account" {
  type        = string
  description = "Google Cloud IAM service account for authenticating with GCP services for GCS"
}

variable "create_ray_cluster" {
  type    = bool
  default = false
}

variable "enable_gpu" {
  type    = bool
  default = false
}

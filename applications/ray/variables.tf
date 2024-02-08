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
  type = string
  description = "require to use connectgateway for private clusters, default: cluster_name"
  default = ""
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

variable "service_account" {
  type        = string
  description = "Google Cloud IAM service account for authenticating with GCP services"
  default     = "myray-system-account"
}

variable "service_account_iam_roles" {
  type        = list(string)
  description = "Google Cloud IAM service account for authenticating with GCP services"
  default = [ "roles/monitoring.viewer" ]
}

variable "create_ray_cluster" {
  type    = bool
  default = false
}

variable "support_tpu" {
  type    = bool
  default = false
}

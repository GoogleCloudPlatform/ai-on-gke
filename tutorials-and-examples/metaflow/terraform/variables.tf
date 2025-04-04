# Copyright 2025 Google LLC
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
  type = string
}
variable "default_resource_name" {
  type = string
}
variable "cluster_name" {
  type = string
}
variable "cluster_location" {
  type = string
}
variable "autopilot_cluster" {
  type = bool
}
variable "private_cluster" {
  type = bool
}
variable "cluster_membership_id" {
  type        = string
  description = "require to use connectgateway for private clusters, default: cluster_name"
  default     = ""
}
variable "service_account_name" {
  type = string
}
variable "bucket_name" {
  type = string
}
variable "network_name" {
  type = string
}
variable "subnetwork_name" {
  type = string
}
variable "subnetwork_cidr" {
  type = string
}

variable "subnetwork_region" {
  type = string
}

variable "subnetwork_private_access" {
  type    = string
  default = "true"
}

variable "subnetwork_description" {
  type    = string
  default = ""
}

variable "metaflow_cloudsql_instance" {
  type    = string
  default = ""
}

variable "metaflow_cloudsql_instance_region" {
  type        = string
  description = "GCP region for CloudSQL instance"
}

variable "metaflow_db_user" {
  type        = string
  description = "Cloud SQL instance user"
  default     = "metaflow-user"
}

variable "metaflow_kubernetes_service_account_name" {
  type = string
}

variable "metaflow_kubernetes_namespace" {
  type = string
}
variable "metaflow_argo_workflows_sa_name" {
  type = string
}

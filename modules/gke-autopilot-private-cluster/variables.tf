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
  default     = "umeshkumhar"
}

variable "region" {
  type        = string
  description = "GCP project region or zone"
  default     = "us-central1"
}

## network variables
variable "network_name" {
  type = string
}

variable "subnetwork_name" {
  type = string
}

## GKE variables
variable "cluster_name" {
  type = string
}

variable "cluster_labels" {
  type        = map
  description = "GKE cluster labels"
}

variable "kubernetes_version" {
  type = string
}

variable "cluster_regional" {
  type = bool
}

variable "cluster_region" {
  type = string
}

variable "cluster_zones" {
  type = list(string)
}
variable "ip_range_pods" {
  type = string
}
variable "ip_range_services" {
  type = string
}

variable "master_authorized_networks" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

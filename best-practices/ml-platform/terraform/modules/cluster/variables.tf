# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "cluster_name" {
  default     = ""
  description = "GKE cluster name"
  type        = string
}

variable "env" {
  description = "environment"
  type        = string
}

variable "initial_node_count" {
  default     = 1
  description = "The number of nodes to create in this cluster's default node pool. In regional or multi-zonal clusters, this is the number of nodes per zone. Must be set if node_pool is not set. If you're using google_container_node_pool objects with no default node pool, you'll need to set this to a value of at least 1, alongside setting remove_default_node_pool to true."
  type        = number
}

variable "machine_type" {
  default     = "e2-medium"
  description = "The name of a Google Compute Engine machine type."
  type        = string
}

variable "master_auth_networks_ipcidr" {
  description = "master authorized network"
  type        = string
}

variable "network" {
  description = "VPC network where the cluster will be created"
  type        = string
}

variable "project_id" {
  default     = ""
  description = "The GCP project where the resources will be created"
  type        = string
}

variable "region" {
  default     = "us-central1"
  description = "The GCP region where the GKE cluster will be created"
  type        = string
}

variable "release_channel" {
  default     = "REGULAR"
  description = "If true, deletes the default node pool upon cluster creation. If you're using google_container_node_pool resources with no default node pool, this should be set to true, alongside setting initial_node_count to at least 1."
  type        = string

  validation {
    condition = contains(
      [
        "RAPID",
        "REGULAR",
        "STABLE",
        "UNSPECIFIED"
      ],
      var.release_channel
    )
    error_message = "'release_channel' value is invalid"
  }
}

variable "remove_default_node_pool" {
  default     = true
  description = "If true, deletes the default node pool upon cluster creation. If you're using google_container_node_pool resources with no default node pool, this should be set to true, alongside setting initial_node_count to at least 1."
  type        = bool
}

variable "subnet" {
  description = "subnetwork where the cluster will be created"
  type        = string
}

variable "zone" {
  default     = "us-central1-a"
  description = "The GCP zone where the reservation will be created"
  type        = string
}

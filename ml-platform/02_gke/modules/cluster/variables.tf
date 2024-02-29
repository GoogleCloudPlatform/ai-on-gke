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

variable "project_id" {
  type        = string
  description = "The GCP project where the resources will be created"
  default     = ""
}
variable "cluster_name" {
  type        = string
  description = "GKE cluster name"
  default     = ""
}

variable "region" {
  type        = string
  description = "The GCP region where the GKE cluster will be created"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "The GCP zone where the reservation will be created"
  default     = "us-central1-a"
}

variable "master_auth_networks_ipcidr" {
  type = string
  description = "master authorized network"
}

variable "network" {
  type = string
  description = "VPC network where the cluster will be created"
}

variable "subnet" {
  type = string
  description = "subnetwork where the cluster will be created"

}

variable "env" {
  type = string
  description = "environment"

}
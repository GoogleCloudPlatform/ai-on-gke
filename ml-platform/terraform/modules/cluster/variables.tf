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

variable "subnet" {
  description = "subnetwork where the cluster will be created"
  type        = string
}

variable "zone" {
  default     = "us-central1-a"
  description = "The GCP zone where the reservation will be created"
  type        = string
}

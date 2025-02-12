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

variable "location_manager" {
  type        = string
  description = "Location of GKE cluster"
  default     = "europe-west4"
}
variable "cluster_manager_name_prefix" {
  type        = string
  description = "Prefix of MultiKueue Manager GKE cluster"
  default     = "manager"
}

variable "regions_workers" {
  type    = list(string)
  default = ["europe-west4", "asia-southeast1", "us-east4"]
}

variable "cluster_worker_names_prefix" {
  type        = string
  description = "Prefix of MultiKueue Workers GKE cluster"
  default     = "worker"
}


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

variable "accelerator" {
  default     = "nvidia-l4"
  description = "The GPU accelerator to use."
  type        = string
}

variable "accelerator_count" {
  default     = 2
  description = "The number of accelerators per machine."
  type        = number
}

variable "autoscaling" {
  default = {
    "total_min_node_count" : 0,
    "total_max_node_count" : 24,
    "location_policy" : "ANY"
  }
  type = map(any)
}

variable "cluster_name" {
  default     = ""
  description = "GKE cluster name"
  type        = string
}

variable "machine_reservation_count" {
  default     = 4
  description = "Number of machines reserved instances with GPUs"
  type        = number
}

variable "machine_type" {
  default     = "g2-standard-24"
  description = "The machine type to use."
  type        = string
}

variable "node_pool_name" {
  description = "Name of the node pool"
  type        = string
}

variable "project_id" {
  default     = ""
  description = "The GCP project where the resources will be created"
  type        = string
}

variable "region" {
  default     = "us-central1-a"
  description = "The GCP zone where the reservation will be created"
  type        = string
}

variable "reservation_name" {
  default     = ""
  description = "reservation name to which the nodepool will be associated"
  type        = string
}

variable "resource_type" {
  default     = "ondemand"
  description = "ondemand/spot/reserved."
  type        = string 
}

variable "taints" {
  description = "Taints to be applied to the on-demand node pool."
  type = list(object({
    effect = string
    key    = string
    value  = any
  }))
}

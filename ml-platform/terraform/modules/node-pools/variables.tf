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

variable "node_pool_name" {
  type        = string
  description = "Name of the node pool"
}
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
  description = "The GCP zone where the reservation will be created"
  default     = "us-central1-a"
}

variable "machine_type" {
  type        = string
  description = "The machine type to use."
  default     = "g2-standard-24"
}

variable "taints" {
  description = "Taints to be applied to the on-demand node pool."
  type = list(object({
    key    = string
    value  = any
    effect = string
  }))
}

variable "resource_type" {
  description = "ondemand/spot/reserved."
  type        = string
  default     = "ondemand"
}


variable "accelerator" {
  type        = string
  description = "The GPU accelerator to use."
  default     = "nvidia-l4"
}

variable "accelerator_count" {
  type        = number
  description = "The number of accelerators per machine."
  default     = 2
}
variable "machine_reservation_count" {
  type        = number
  description = "Number of machines reserved instances with GPUs"
  default     = 4
}

variable "autoscaling" {
  type    = map(any)
  default = { "total_min_node_count" : 0, "total_max_node_count" : 24, "location_policy" : "ANY" }
}

variable "reservation_name" {
  description = "reservation name to which the nodepool will be associated"
  type        = string
  default     = ""
}

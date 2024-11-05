# Copyright 2023 Google LLC
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

variable "region" {
  type        = string
  description = "The GCP region where the GKE cluster will be created"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "The GCP zone where the reservation will be created"
  default     = "us-central1-c"
}

variable "machine_type" {
  type        = string
  description = "The machine type to use."
  default     = "g2-standard-24"
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

# Pattern adopted from https://github.com/GoogleCloudPlatform/hpc-toolkit/blob/main/community/modules/scheduler/gke-cluster/variables.tf

variable "reserved_taints" {
  description = "Taints to be applied to the on-demand node pool."
  type = list(object({
    key         = string
    taint_value = any
    effect      = string
  }))
  default = [{
    key         = "reserved"
    taint_value = true
    effect      = "NO_SCHEDULE"
  }]
}

variable "ondemand_taints" {
  description = "Taints to be applied to the on-demand node pool."
  type = list(object({
    key         = string
    taint_value = any
    effect      = string
  }))
  default = [{
    key         = "ondemand"
    taint_value = true
    effect      = "NO_SCHEDULE"
  }]
}

variable "spot_taints" {
  description = "Taints to be applied to the spot node pool."
  type = list(object({
    key         = string
    taint_value = any
    effect      = string
  }))
  default = [{
    key         = "spot"
    taint_value = true
    effect      = "NO_SCHEDULE"
  }]
}

variable "machine_reservation_count" {
  type        = number
  description = "Number of reserved VMs with GPUs"
  default     = 4
}

variable "team_a_namespace" {
  type        = string
  description = "team-a namespace"
  default     = "team-a"
}

variable "team_b_namespace" {
  type        = string
  description = "team-b namespace"
  default     = "team-b"
}

variable "team_c_namespace" {
  type        = string
  description = "team-c namespace"
  default     = "team-c"
}

variable "team_d_namespace" {
  type        = string
  description = "team-d namespace"
  default     = "team-d"
}

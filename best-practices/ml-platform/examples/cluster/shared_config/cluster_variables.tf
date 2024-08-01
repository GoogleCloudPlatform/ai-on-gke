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

locals {
  cluster_name         = "${var.cluster_name_prefix}-${var.environment_name}"
  kubeconfig_directory = abspath("${path.module}/../kubeconfig")
  kubeconfig_file      = abspath("${local.kubeconfig_directory}/${local.cluster_name}")
}

variable "cluster_name_prefix" {
  default     = "mlp"
  description = "Name of the GKE cluster"
  type        = string
}

variable "enable_private_endpoint" {
  default     = true
  description = "When true, the cluster's private endpoint is used as the cluster endpoint and access through the public endpoint is disabled. When false, either endpoint can be used. This field only applies to private clusters, when enable_private_nodes is true."
  type        = bool
}

variable "environment_name" {
  default     = "dev"
  description = "Name of the environment"
  type        = string
}

variable "environment_project_id" {
  description = "The GCP project where the resources will be created"
  type        = string

  validation {
    condition     = var.environment_project_id != ""
    error_message = "'environment_project_id' was not set, please set the value in the mlp.auto.tfvars file"
  }
}

variable "gpu_driver_version" {
  default     = "LATEST"
  description = "Mode for how the GPU driver is installed."
  type        = string

  validation {
    condition = contains(
      [
        "DEFAULT",
        "GPU_DRIVER_VERSION_UNSPECIFIED",
        "INSTALLATION_DISABLED",
        "LATEST"
      ],
      var.gpu_driver_version
    )
    error_message = "'gpu_driver_version' value is invalid"
  }
}

variable "namespace" {
  default     = "ml-team"
  description = "Name of the namespace to demo."
  type        = string
}

variable "ondemand_taints" {
  default = [{
    key    = "ondemand"
    value  = true
    effect = "NO_SCHEDULE"
  }]
  description = "Taints to be applied to the on-demand node pool."
  type = list(object({
    key    = string
    value  = any
    effect = string
  }))
}

variable "region" {
  default     = "us-central1"
  description = "Region used to create resources"
  type        = string

  validation {
    condition = contains(
      [
        "us-central1"
      ],
    var.region)
    error_message = "'region' must be 'us-central1' "
  }
}

variable "reserved_taints" {
  default = [{
    key    = "reserved"
    value  = true
    effect = "NO_SCHEDULE"
  }]
  description = "Taints to be applied to the reserved node pool."
  type = list(object({
    key    = string
    value  = any
    effect = string
  }))
}

variable "spot_taints" {
  default = [{
    key    = "spot"
    value  = true
    effect = "NO_SCHEDULE"
  }]
  description = "Taints to be applied to the spot node pool."
  type = list(object({
    key    = string
    value  = any
    effect = string
  }))
}

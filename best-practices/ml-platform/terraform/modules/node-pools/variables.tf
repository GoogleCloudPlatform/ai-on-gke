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

variable "autoscaling" {
  default = {
    location_policy      = "ANY"
    total_max_node_count = 24
    total_min_node_count = 0
  }
  description = "Configuration required by cluster autoscaler to adjust the size of the node pool to the current cluster usage"
  type = object(
    {
      location_policy      = string
      total_max_node_count = number
      total_min_node_count = number
    }
  )
}

variable "cluster_name" {
  default     = ""
  description = "GKE cluster name"
  type        = string
}

variable "guest_accelerator" {
  default     = null
  description = "List of the type and count of accelerator cards attached to the instance."
  type = object(
    {
      count = number
      type  = string
      gpu_driver_installation_config = object(
        {
          gpu_driver_version = string
        }
      )
    }
  )
}

variable "initial_node_count" {
  default     = 0
  description = "The initial number of nodes for the pool. In regional or multi-zonal clusters, this is the number of nodes per zone. Changing this will force recreation of the resource."
  type        = number
}

variable "location" {
  default     = "us-central1-a"
  description = "The location (region or zone) of the node pool."
  type        = string
}

variable "reservation_affinity" {
  default     = null
  description = "The configuration of the desired reservation which instances could take capacity from."
  type = object(
    {
      consume_reservation_type = string
      key                      = string
      values                   = list(string)
    }
  )
}

variable "machine_type" {
  default     = "g2-standard-24"
  description = "The name of a Google Compute Engine machine type."
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

variable "resource_type" {
  default     = "ondemand"
  description = "ondemand/spot/reserved."
  type        = string
}

variable "taints" {
  default     = []
  description = "A list of Kubernetes taints to apply to nodes."
  type = list(object({
    effect = string
    key    = string
    value  = any
  }))
}

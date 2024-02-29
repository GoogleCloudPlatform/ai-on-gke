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
  type        = map
  description = "The GCP project where the resources will be created. It is a map with environments a skeys and project_ids s values"
  default     = {}
  #Below is an example of not null project_id variable
  #default    = { "dev" : "project_id1", "staging" : "project_id2", "prod" : "project_id3" }
}

variable "network_name" {
  default = "ml-vpc"
  description = "VPC network where GKE cluster will be created"
  type = string
}
variable "routing_mode" {
  default = "GLOBAL"
  description = "VPC routing mode."
  type = string
}
variable "subnet_01_name" {
  default = "ml-vpc-subnet-01"
  description = "Name of the first subnet in the VPC network."
  type = string
}
variable "subnet_01_ip" {
  default = "10.40.0.0/22"
  description = "CIDR of the first subnet."
  type = string
}
variable "subnet_01_region" {
  default = "us-central1"
  description = "Region of the first subnet."
  type = string
}
variable "subnet_01_description" {
  default = "subnet 01"
  description = "Description of the first subnet."
  type = string
}
variable "subnet_02_name" {
  default = "gke-vpc-subnet-02"
  description = "Name of the second subnet in the VPC network."
  type = string
}
variable "subnet_02_ip" {
  default = "10.12.0.0/22"
  description = "CIDR of the second subnet."
  type = string
}
variable "subnet_02_region" {
  default = "us-west2"
  description = "Region of the second subnet."
  type = string
}
variable "subnet_02_description" {
  default = "subnet 02"
  description = "Description of the second subnet."
  type = string
}

variable "lookup_state_bucket" {
  description = "GCS bucket to look up TF state from previous steps."
  type = string
  default = "YOUR_STATE_BUCKET"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  default = "gke-ml"
  type = string
}
variable "reserved_taints" {
  description = "Taints to be applied to the reserved node pool."
  type = list(object({
    key    = string
    value  = any
    effect = string
  }))
  default = [{
    key    = "reserved"
    value  = true
    effect = "NO_SCHEDULE"
  }]
}

variable "ondemand_taints" {
  description = "Taints to be applied to the on-demand node pool."
  type = list(object({
    key    = string
    value  = any
    effect = string
  }))
  default = [{
    key    = "ondemand"
    value  = true
    effect = "NO_SCHEDULE"
  }]
}

variable "spot_taints" {
  description = "Taints to be applied to the spot node pool."
  type = list(object({
    key    = string
    value  = any
    effect = string
  }))
  default = [{
    key    = "spot"
    value  = true
    effect = "NO_SCHEDULE"
  }]
}


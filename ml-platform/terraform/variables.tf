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

variable "org_id" {
  type        = string
  description = "The GCP orig id"
  default     = null
}

variable "env" {
  type        = set(string)
  description = "List of environments"
  default     = ["dev"]
}

variable "default_env" {
  type        = string
  description = "Lowest environments"
  default     = "dev"
}

variable "folder_id" {
  type        = string
  description = "Folder Id where the GCP projects will be created"
  default     = null
}

variable "billing_account" {
  type        = string
  description = "GCP billing account"
  default     = null
}

variable "project_name" {
  type        = string
  description = "GCP project name"
  default     = null
}

variable "create_projects" {
  type        = number
  description = "Flag to create GCP projects"
  default     = 0
}

variable "project_id" {
  type        = map(any)
  description = "The GCP project where the resources will be created. It is a map with environments as keys and project_ids s values"
}

variable "network_name" {
  default     = "ml-vpc"
  description = "VPC network where GKE cluster will be created"
  type        = string
}

variable "routing_mode" {
  default     = "GLOBAL"
  description = "VPC routing mode."
  type        = string
}

variable "subnet_01_name" {
  default     = "ml-vpc-subnet-01"
  description = "Name of the first subnet in the VPC network."
  type        = string
}

variable "subnet_01_ip" {
  default     = "10.40.0.0/22"
  description = "CIDR of the first subnet."
  type        = string
}

variable "subnet_01_region" {
  default     = "us-central1"
  description = "Region of the first subnet."
  type        = string
}

variable "subnet_01_description" {
  default     = "subnet 01"
  description = "Description of the first subnet."
  type        = string
}

variable "subnet_02_name" {
  default     = "gke-vpc-subnet-02"
  description = "Name of the second subnet in the VPC network."
  type        = string
}

variable "subnet_02_ip" {
  default     = "10.12.0.0/22"
  description = "CIDR of the second subnet."
  type        = string
}

variable "subnet_02_region" {
  default     = "us-west2"
  description = "Region of the second subnet."
  type        = string
}

variable "subnet_02_description" {
  default     = "subnet 02"
  description = "Description of the second subnet."
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  default     = "gke-ml"
  type        = string
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

variable "configsync_repo_name" {
  type        = string
  description = "Name of the GitHub repo that will be synced to the cluster with Config sync."
  default     = "config-sync-repo"
}

variable "github_user" {
  description = "GitHub user name."
  type        = string
}

variable "github_email" {
  description = "GitHub user email."
  type        = string
}

variable "github_org" {
  type        = string
  description = "GitHub org."
}

variable "github_token" {
  type        = string
  description = "GitHub token. It is a token with write permissions as it will create a repo in the GitHub org."
}

variable "secret_for_rootsync" {
  type        = number
  description = "Create git-cred in config-management-system namespace."
  default     = 1
}

variable "create_namespace" {
  type        = number
  description = "Setup a namespace to demo."
  default     = 1
}

variable "namespace" {
  type        = string
  description = "Name of the namespace to demo."
  default     = "ml-team"
}

variable "install_kuberay" {
  type        = number
  description = "Flag to install kuberay operator."
  default     = 1
}

variable "install_ray_in_ns" {
  type        = number
  description = "Flag to install ray cluster in the namespace created with the demo."
  default     = 1
}

variable "config_management_version" {
  type        = string
  description = "Version of Config Management to enable"
  default     = "1.17.1"
}

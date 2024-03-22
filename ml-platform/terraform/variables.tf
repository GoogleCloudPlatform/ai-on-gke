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
variable "billing_account" {
  default     = null
  description = "GCP billing account"
  type        = string
}

variable "cluster_name" {
  default     = "gke-ml"
  description = "Name of the GKE cluster"
  type        = string
}

variable "config_management_version" {
  default     = "1.17.1"
  description = "Version of Config Management to enable"
  type        = string
}

variable "configsync_repo_name" {
  default     = "config-sync-repo"
  description = "Name of the GitHub repo that will be synced to the cluster with Config sync."
  type        = string
}

variable "create_namespace" {
  description = "Setup a namespace to demo."
  default     = 1
  type        = number
}

variable "create_projects" {
  default     = 0
  description = "Flag to create GCP projects"
  type        = number
}

variable "environment_name" {
  default     = "dev"
  description = "Lowest environments"
  type        = string
}

variable "environment_project_id" {
  description = "The GCP project where the resources will be created"
  type        = string
}

variable "env" {
  default     = ["dev"]
  description = "List of environments"
  type        = set(string)
}

variable "folder_id" {
  default     = null
  description = "Folder Id where the GCP projects will be created"
  type        = string
}

variable "github_email" {
  description = "GitHub user email."
  type        = string
}

variable "github_org" {
  description = "GitHub org."
  type        = string
}

variable "github_token" {
  description = "GitHub token. It is a token with write permissions as it will create a repo in the GitHub org."
  type        = string
}

variable "github_user" {
  description = "GitHub user name."
  type        = string
}

variable "install_kuberay" {
  default     = 1
  description = "Flag to install kuberay operator."
  type        = number
}

variable "install_ray_in_ns" {
  default     = 1
  description = "Flag to install ray cluster in the namespace created with the demo."
  type        = number
}

variable "namespace" {
  default     = "ml-team"
  description = "Name of the namespace to demo."
  type        = string
}

variable "network_name" {
  default     = "ml-vpc"
  description = "VPC network where GKE cluster will be created"
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

variable "org_id" {
  default     = null
  description = "The GCP orig id"
  type        = string
}

variable "project_name" {
  default     = "mlp"
  description = "GCP project name"
  type        = string
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

variable "routing_mode" {
  default     = "GLOBAL"
  description = "VPC routing mode."
  type        = string
}

variable "secret_for_rootsync" {
  default     = 1
  description = "Create git-cred in config-management-system namespace."
  type        = number

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

variable "subnet_01_description" {
  default     = "subnet 01"
  description = "Description of the first subnet."
  type        = string
}

variable "subnet_01_ip" {
  default     = "10.40.0.0/22"
  description = "CIDR of the first subnet."
  type        = string
}

variable "subnet_01_name" {
  default     = "ml-vpc-subnet-01"
  description = "Name of the first subnet in the VPC network."
  type        = string
}

variable "subnet_01_region" {
  default     = "us-central1"
  description = "Region of the first subnet."
  type        = string
}

variable "subnet_02_description" {
  default     = "subnet 02"
  description = "Description of the second subnet."
  type        = string
}

variable "subnet_02_ip" {
  default     = "10.12.0.0/22"
  description = "CIDR of the second subnet."
  type        = string
}

variable "subnet_02_name" {
  default     = "gke-vpc-subnet-02"
  description = "Name of the second subnet in the VPC network."
  type        = string
}

variable "subnet_02_region" {
  default     = "us-west2"
  description = "Region of the second subnet."
  type        = string
}

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

variable "cluster_name_prefix" {
  default     = "mlp"
  description = "GKE cluster name prefix"
  type        = string
}

variable "config_management_version" {
  default     = "1.17.1"
  description = "Version of Config Management to enable"
  type        = string
}

variable "configsync_repo_name" {
  default     = "mlp-configsync"
  description = "Name of the GitHub repo that will be synced to the cluster with Config sync."
  type        = string
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
    condition     = var.environment_project_id != "YOUR_PROJECT_ID"
    error_message = "'environment_project_id' was not set, please set the value in the mlp.auto.tfvars file"
  }
}

variable "env" {
  default     = ["dev"]
  description = "List of environments"
  type        = set(string)
}

variable "git_namespace" {
  description = "The namespace of the git repository"
  type        = string

  validation {
    condition     = var.git_namespace != "YOUR_GIT_NAMESPACE"
    error_message = "'git_namespace' was not set, please set the value in the mlp.auto.tfvars file"
  }
}

variable "git_token" {
  description = "The token with permissions to create the project/repository in the namespace."
  type        = string
}

variable "git_user_email" {
  description = "The user email to configure for git"
  type        = string

  validation {
    condition     = var.git_user_email != "YOUR_GIT_USER_EMAIL"
    error_message = "'git_user_email' was not set, please set the value in the mlp.auto.tfvars file"
  }
}

variable "git_user_name" {
  description = "The user name to configure for git"
  type        = string

  validation {
    condition     = var.git_user_name != "YOUR_GIT_USER"
    error_message = "'github_user' was not set, please set the value in the mlp.auto.tfvars file"
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

variable "iap_domain" {
  default     = null
  description = "IAP domain"
  type        = string
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

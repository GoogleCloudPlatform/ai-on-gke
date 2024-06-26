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

variable "full_management" {
    description = "Use a fully managed (Autopilot) cluster"
    type = bool
}

variable "kubeconfig_directory" {
    description = "Path to store the kubeconfig"
    type = string   
}

variable "location" {
    description = "Location of the config controller cluster"
    type = string   
}

variable "project_id" {
    description = "Project ID for the config controller cluster"
    type = string
}

variable "name" {
    description = "Name of the config controller cluster"
    type = string   
}

variable "network" {
    description = "Existing VPC Network to use for the config controller cluster and nodes"
    type = string
}

variable "subnet" {
    description = "Specifies the subnet that the VM instances are a part of"
    type = string
}

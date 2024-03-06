# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "gcs_bucket" {
  type        = string
  description = "GCS Bucket name"
}

// pv, pvc
variable "pv_name" {
  type        = string
  description = "Name of the PersistentVolume used for DLIO dataset"
}

variable "pvc_name" {
  type        = string
  description = "Name of the PersistentVolumeClaim used for DLIO dataset"
}

variable "storageclass" {
  type        = string
  description = "Name of the storageclass"
}

variable "project" {
  type        = string
  description = "The project name in which the Parallelstore instance is provisioned"
}

variable "location" {
  type = string
}

variable "ps_instance_name" {
  type = string
}

variable "ps_ip_address_1" {
  type = string
}

variable "ps_ip_address_2" {
  type = string
}

variable "ps_ip_address_3" {
  type = string
}

variable "ps_network_name" {
  type = string
}

variable "k8s_service_account" {
  type        = string
  description = "Kubernetes service account name as in the Configure access to Cloud Storage buckets using GKE Workload Identity step"
}

variable "run_parallelstore_data_loader" {
  type = string
}

variable "namespace" {
  type = string
}

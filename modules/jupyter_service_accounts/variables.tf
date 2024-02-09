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

variable "project_id" {
  type        = string
  description = "GCP project id"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace where resources are deployed"
}

variable "gcp_service_account" {
  type        = string
  description = "Google Cloud IAM service account for authenticating with GCP services"
}

variable "gcp_sa_iam_roles" {
  type        = list(string)
  description = "Service Account Project IAM binding roles"
}

variable "create_k8s_service_account" {
  type        = bool
  description = "Create k8s service account"
}

variable "k8s_service_account" {
  type        = string
  description = "K8S service account name"
}
